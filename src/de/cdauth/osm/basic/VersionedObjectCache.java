package de.cdauth.osm.basic;

import java.util.Collections;
import java.util.Hashtable;
import java.util.SortedMap;
import java.util.TreeMap;

/**
 * This class extends the {@link ObjectCache} class to be able to additionally cache old versions of {@link VersionedObject}s.
 * As a VersionedObject does not know if it is the current one, you have to use special methods if you fetch
 * current object versions; if you deal with old versions or whole history trees, use the other methods of this class.
 * @author cdauth
 */
public class VersionedObjectCache<T extends VersionedObject> extends ObjectCache<T>
{
	/**
	 * How many entries may be in the cache?
	 */
	public static final int MAX_CACHED_VALUES = 1000;
	/**
	 * How old may the entries in the cache be at most?
	 */
	public static final int MAX_AGE = 86400;

	private final Hashtable<ID,TreeMap<Version,T>> m_history = new Hashtable<ID,TreeMap<Version,T>>();
	private final SortedMap<Long,ID> m_historyTimes = Collections.synchronizedSortedMap(new TreeMap<Long,ID>());
	
	/**
	 * Returns a specific version of the object with the ID a_id.
	 * @param a_id The ID of the object.
	 * @param a_version The version to look up in the cache.
	 * @return The object of the specified version or null if is not in the cache.
	 */
	public T getObject(ID a_id, Version a_version)
	{
		TreeMap<Version,T> history = getHistory(a_id);
		if(history == null)
			return null;
		synchronized(history)
		{
			return history.get(a_version);
		}
	}
	
	/**
	 * Returns the whole history of the object. The history is considered to be cached when all versions of it
	 * are definitely in the cache (which is the case when the current version is saved and all versions from 1 
	 * to the current one’s version number are existant).
	 * @param a_id The ID of the object.
	 * @return The whole history of the object or null if it is not complete in the cache.
	 */
	public TreeMap<Version,T> getHistory(ID a_id)
	{
		synchronized(m_history)
		{
			TreeMap<Version,T> history = m_history.get(a_id);
			if(history == null)
				return null;
			
			// Check if all versions have been fetched into history
			T current = getObject(a_id);
			if(current == null)
				return null;
			Version currentVersion = current.getVersion();
			
			for(long i=1; i<=currentVersion.asLong(); i++)
			{
				if(!history.containsKey(new Long(i)))
					return null;
			}
			return history;
		}
	}
	
	/**
	 * Caches an specific version ({@link VersionedObject#getVersion}) of an object.
	 * @param a_object The versioned object to cache.
	 */
	@Override
	public void cacheObject(T a_object)
	{
		if(a_object.isCurrent())
			super.cacheObject(a_object);

		Version version = a_object.getVersion();
		if(version == null)
			return;
		ID id = a_object.getID();
		TreeMap<Version,T> history;
		synchronized(m_history)
		{
			history = getHistory(id);
			if(history == null)
			{
				history = new TreeMap<Version,T>();
				m_history.put(id, history);
			}
			
			synchronized(m_historyTimes)
			{
				m_historyTimes.put(System.currentTimeMillis(), id);
			}
		}
		synchronized(history)
		{
			history.put(version, a_object);
		}
	}
	
	/**
	 * Caches the whole history of an object.
	 * @param a_history The whole history of an object.
	 */
	public void cacheHistory(TreeMap<Version,T> a_history)
	{
		if(a_history.size() < 1)
			return;
		
		T current = a_history.lastEntry().getValue();
		if(current.isCurrent()) // Should always be true
			super.cacheObject(current);

		synchronized(m_history)
		{
			m_history.put(current.getID(), a_history);
		}
	}
	
	@Override
	protected void cleanUp()
	{
		super.cleanUp();
		while(true)
		{
			synchronized(m_history)
			{
				synchronized(m_historyTimes)
				{
					Long oldest = m_historyTimes.firstKey();
					if(oldest == null || (System.currentTimeMillis()-oldest <= MAX_AGE*1000 && m_historyTimes.size() <= MAX_CACHED_VALUES))
						break;
					ID id = m_historyTimes.remove(oldest);
					m_history.remove(id);
				}
			}
		}
	}
}
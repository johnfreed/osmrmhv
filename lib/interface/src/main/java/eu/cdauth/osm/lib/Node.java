/*
	This file is in the public domain, furnished “as is”, without technical
	support, and with no warranty, express or implied, as to its usefulness for
	any purpose.
*/

package eu.cdauth.osm.lib;

/**
 * A node in OSM is a versioned object that consists of an ID, a position and tags.
 * @author cdauth
 */
public interface Node extends GeographicalItem, VersionedItem
{
	/**
	 * Returns a LonLat object for the coordinates of this node.
	 * @return The coordinates of this node.
	 */
	public LonLat getLonLat();
	
	/**
	 * Returns the ID of all ways that currently contain the <strong>current</strong> version of this node.
	 * @return An array of the IDs of all ways that currently contain this node.
	 * @throws APIError The ways could not be fetched.
	 */
	public ID[] getContainingWays() throws APIError;
}

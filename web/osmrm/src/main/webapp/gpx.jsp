<%--
	This file is part of the OSM Route Manager.

	OSM Route Manager is free software: you can redistribute it and/or modify
	it under the terms of the GNU Affero General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	OSM Route Manager is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU Affero General Public License for more details.

	You should have received a copy of the GNU Affero General Public License
	along with this software. If not, see <http://www.gnu.org/licenses/>.

	Copyright © 2010 Candid Dauth
--%>
<%@page import="eu.cdauth.osm.lib.*"%>
<%@page import="eu.cdauth.osm.web.osmrm.*"%>
<%@page import="eu.cdauth.osm.web.common.Cache"%>
<%@page import="eu.cdauth.osm.web.common.Queue"%>
<%@page import="java.util.*" %>
<%@page import="static eu.cdauth.osm.web.osmrm.GUI.*"%>
<%@page contentType="text/xml; charset=UTF-8" buffer="none" session="false"%>
<%!
	private static final API api = GUI.getAPI();
	private static Cache<RouteAnalyser> cache = null;
	private static final Queue queue = Queue.getInstance();

	public void jspInit()
	{
		if(cache == null)
		{
			cache = new Cache<RouteAnalyser>(GUI.getCacheDirectory(getServletContext())+"/osmrm");
			cache.setMaxAge(86400);
		}

		RouteAnalyser.cache = cache;
		RouteAnalyser.api = api;

		GUI.servletStart();
	}

	public void jspDestroy()
	{
		GUI.servletStop();
	}
%>
<%
	response.setHeader("Content-disposition", "attachment; filename=route.gpx");

	ID relationId = (request.getParameter("relation") != null ? new ID(request.getParameter("relation")) : null);
	RouteAnalyser route = null;
	if(relationId != null)
	{
		Cache.Entry<RouteAnalyser> cacheEntry = cache.getEntry(relationId.toString());
		int queuePosition = queue.getPosition(RouteAnalyser.WORKER, relationId);
		if(cacheEntry == null)
		{
			if(queuePosition == 0)
			{
				Queue.Notification notify = queue.scheduleTask(RouteAnalyser.WORKER, relationId);
				notify.sleep(0);
				cacheEntry = cache.getEntry(relationId.toString());
				queuePosition = queue.getPosition(RouteAnalyser.WORKER, relationId);
			}
		}

		if(cacheEntry != null)
			route = cacheEntry.content;
	}

	if(route != null)
	{
		String ref = route.tags.get("ref").trim();
		if(!ref.equals(""))
			response.setHeader("Content-disposition", "attachment; filename="+urlencode(ref)+".gpx");
		else
		{
			String name = route.tags.get("name").trim();
			if(!name.equals(""))
				response.setHeader("Content-disposition", "attachment; filename="+urlencode(name)+".gpx");
		}
	}
%>
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="OSM Route Manager" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
<!-- All data by OpenStreetMap, licensed under cc-by-sa-2.0 (http://creativecommons.org/licenses/by-sa/2.0/). -->
<%
	if(relationId != null && route != null)
	{
		try
		{
%>
	<rte>
		<name><%=htmlspecialchars(route.tags.get("name"))%></name>
<%
			if(!route.tags.get("description").equals(""))
			{
%>
		<desc><%=htmlspecialchars(route.tags.get("description"))%></desc>
<%
			}
%>
		<src>OpenStreetMap.org</src>
<%
			if(!route.tags.get("url").equals(""))
			{
%>
		<link href="<%=htmlspecialchars(route.tags.get("url"))%>" />
<%
			}

			if(!route.tags.get("route").equals(""))
			{
%>
		<type><%=htmlspecialchars(route.tags.get("route"))%></type>
<%
			}

			List<Integer> desiredSegments = null;
			List<Boolean> desiredSegmentsReverse = null;

			if(request.getParameter("segments") != null)
			{
				String[] desiredSegmentsS = request.getParameter("segments").split(",");
				desiredSegments = new ArrayList<Integer>();
				desiredSegmentsReverse = new ArrayList<Boolean>();
				for(String desiredSegment : desiredSegmentsS)
				{
					try {
						if(desiredSegment.length() < 2)
							continue;
						int number = Integer.parseInt(desiredSegment.substring(1));
						if(number < 0 || number >= route.segments.length)
							continue;
						if(desiredSegment.charAt(0) == '-')
							desiredSegmentsReverse.add(true);
						else if(desiredSegment.charAt(0) == '+')
							desiredSegmentsReverse.add(false);
						else
							continue;
						desiredSegments.add(number);
					} catch(NumberFormatException e) {
						continue;
					}
				}

				if(desiredSegments.size() == 0)
				{
					desiredSegments = null;
					desiredSegmentsReverse = null;
				}
			}

			int maxI = (desiredSegments == null ? route.segments.length : desiredSegments.size());
			LonLat lastPoint = null;
			for(int i=0; i<maxI; i++)
			{
				RelationSegment it;
				if(desiredSegments == null)
					it = route.segments[i];
				else
					it = route.segments[desiredSegments.get(i)];
				LonLat[] nodes = it.getNodes();
				boolean reverse = (desiredSegments != null && desiredSegmentsReverse.get(i));

				for(int j=(reverse ? nodes.length-1 : 0); (reverse ? j >= 0 : j < nodes.length); j += (reverse ? -1 : 1))
				{
					if(lastPoint != null)
					{
						if(lastPoint == nodes[j])
						{ // Skip duplicated points at segment and and start
							lastPoint = null;
							continue;
						}
						lastPoint = null;
					}
%>
		<rtept lat="<%=htmlspecialchars(""+nodes[j].getLat())%>" lon="<%=htmlspecialchars(""+nodes[j].getLon())%>" />
<%
				}
				lastPoint = nodes[reverse ? 0 : nodes.length-1];
			}
%>
	</rte>
<%
		}
		catch(Exception e)
		{
		}
	}
%>
</gpx>

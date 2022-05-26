package me.Secret.CommonCore.Permissions;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.UUID;

import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.permissions.PermissionAttachment;
import org.bukkit.plugin.Plugin;

import me.Secret.CommonCore.Util;

public class Permission {
	private Groups defaultGroup;
	private Plugin plugin;
	private HashMap<UUID, PermissionAttachment> playerPermission = new HashMap<>();
	private List<Groups> groups = new ArrayList<Groups>();//we create a list of groups, these groups store the permission for each group. So we dont have to load them each time
	public Permission(Plugin plugin) {
		this.plugin=plugin;//create an instance of plugin so we can use .getConfig (Annoying)
		loadPermissions();
	}
	public void setupPLayer(Player player) {//This is the setup player method. We will run this every time a player joins the server
		PermissionAttachment attachment = player.addAttachment(plugin);
		playerPermission.put(player.getUniqueId(), attachment);
		for(Groups ListGroups: groups) {//we cycle through all of the groups we have loaded
			if(ListGroups.setupPlayer(attachment, player.getUniqueId())) {//THis acts as both an if statment and as our loader loading the permissions of each player
				player.setDisplayName(Util.convert(ListGroups.getTitle()+" "+player.getName()+"&7"));
				//System.out.println("Player "+player.getName()+" loaded successfully");
			}
		}
		if(getGroup(player.getUniqueId()).size() > 0 ) {
			return;
		}//If we get to this point we know the player is not in a group
		defaultGroup.setupPlayer(attachment, player.getUniqueId());//We set up the players permissions as if they were in the default group
		defaultGroup.addPlayer(player.getUniqueId());//then we add the player to the default group
		player.setDisplayName(Util.convert(defaultGroup.getTitle()+" "+player.getName()+"&7"));
		//System.out.println("Player "+player.getName()+" set as default successfully");
		
	}
	public void loadPermissions() {//this method loads the groups and theirs members and their permissions
		for(String groups: plugin.getConfig().getConfigurationSection("Groups").getKeys(false)) {
			Groups newGroup = new Groups(groups);
			//System.out.println("We have added the new group "+newGroup.getName());
			this.groups.add(newGroup);//add the new group to the list of groups
			//System.out.println("We have found the title "+plugin.getConfig().getString("Groups."+groups+".title")+" for the group "+newGroup.getName());
			newGroup.setTitle(plugin.getConfig().getString("Groups."+groups+".title"));
			if(plugin.getConfig().getString("Groups."+groups+".default").equalsIgnoreCase("true")) {
				//System.out.println("Setting the group "+newGroup.getName()+" as the default group");
				defaultGroup = newGroup;
			}
			for(String permissions: plugin.getConfig().getStringList("Groups."+groups+".permissions")) {
				newGroup.addPermission(permissions);
				//System.out.println("adding permission "+permissions+" to group "+newGroup.getName());
			}
			for(String members: plugin.getConfig().getStringList("Groups."+groups+".members")) {
				newGroup.addPlayer(UUID.fromString(members));
				//System.out.println("adding player "+members+" to group "+newGroup.getName());
			}
		}
	}
	public void unloadPermissionsAndGroups() {//this method unloads (Writes to the file) all the groups their permissions and new players
		System.out.println("We are unloading all of the groups!");
		plugin.getConfig();
		plugin.saveConfig();
		for(Groups group: groups) {	
			List<String> membersUUIDs = new ArrayList<String>();
			for(UUID members: group.getPlayers()) {
				membersUUIDs.add(members.toString());
				//System.out.println(members.toString());
			}
			if(membersUUIDs.size()==0) {
				plugin.getConfig().set("Groups."+group.getName()+".members", "null");
			}
			else {
				plugin.getConfig().set("Groups."+group.getName()+".members", membersUUIDs);
			}
		}
		plugin.saveConfig();
		
		
	}
	public HashMap<UUID, PermissionAttachment> getPermissions(){
		return playerPermission;
	}
	public List<Groups> getGroup(UUID player) {
		List<Groups> listOfGroups = new ArrayList<Groups>(); 
		for(Groups group: groups) {
			if(group.containPlayer(player)) {
				listOfGroups.add(group);//if we find the player in a group we will return the group
			}
		}
		return listOfGroups;
	}
	public Groups getGroup(String name) {
		for(Groups group: groups) {
			if(group.getName().equalsIgnoreCase(name)) {
				return group;//if we find the group with the corresponding name we will return the group
			}
		}
		return null;
	}
	public void reloadPlayer(UUID player) {
		playerPermission.get(player);
		Player offlinePlayer = (Player)Bukkit.getOfflinePlayer(player);
		setupPLayer(offlinePlayer);
		
	}
	public List<Groups> getGroups(){
		return groups;
	}
	public void removePlayerFromGroup(UUID player, Groups group) {
		group.removePlayer(player, playerPermission.get(player));
		reloadPlayer(player);//we reload the player after they have been removed from a group to reset their permissions
		
	}
	

}

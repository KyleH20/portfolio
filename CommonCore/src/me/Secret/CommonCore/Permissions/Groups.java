package me.Secret.CommonCore.Permissions;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.permissions.PermissionAttachment;

public class Groups {
	private String name;//declare the variables of the group
	private List<UUID> players = new ArrayList<UUID>();
	private List<String> permissions = new ArrayList<String>();
	private String title="&Cdefault";
	
	public Groups(String name) {
		this.name = name;//set group name
	}
	public void addPermission(String permission) {
		permissions.add(permission);//add the permissions the group will need
	}
	public String getName() {
		return name;//get the name of the group
	}
	public boolean setupPlayer(PermissionAttachment attachment, UUID uuid) {//this is the player setup
		if(players.contains(uuid)) {//if the player is in our group
			for(String permission: permissions) {//we will loop through our permission
				attachment.setPermission(permission, true);//and add them to that player
				//attachment.remove();
			}//we recieve the permissions from the Permissions along with the attachment objects 
			return true;
		}
		return false;
	}
	public void addPlayer(UUID player) {
		players.add(player);
		for(Player onlinePlayers: Bukkit.getOnlinePlayers()) {
			if(onlinePlayers.getUniqueId().equals(player)) {
				onlinePlayers.setCustomName(title+onlinePlayers.getName());
				onlinePlayers.setCustomNameVisible(true);
			}
		}
	}
	public void removePlayer(UUID player,PermissionAttachment attachment) {
		for(String permission: permissions) {
			attachment.unsetPermission(permission);
		}
		players.remove(player);
	}
	public boolean containPlayer(UUID player) {
		if(players.contains(player))//if the list contains the player return true else return false
			return true;
		
		return false;
	}
	public void setTitle(String title) {
		this.title=title;//this is the "Rank" of each group. So admin will be like $CAdmin and will print out before the users name 
	}
	public String getTitle() {
		return title;
	}
	public List<String> getPermissions() {
		return permissions;
	}
	public List<UUID> getPlayers(){
		return players;
	}
	

}

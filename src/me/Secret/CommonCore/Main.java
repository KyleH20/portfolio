package me.Secret.CommonCore;

import java.util.HashMap;
import java.util.UUID;

import org.bukkit.event.Listener;
import org.bukkit.permissions.PermissionAttachment;
import org.bukkit.plugin.java.JavaPlugin;

import me.Secret.CommonCore.Permissions.Permission;

public class Main extends JavaPlugin implements Listener{
	public static String version = "Beta .1";
	public HashMap<UUID, PermissionAttachment> playerPermission = new HashMap<>();//This will probably be removed in a future update
	public Permission p;
	@Override
	public void onEnable() {
		this.getConfig();
		this.saveConfig();
		//this.saveConfig();
		this.p = new Permission(this);//Ugh you have to remember how to create higher objects!
		playerPermission = p.getPermissions();
		
		this.getServer().getPluginManager().registerEvents(new CommonCoreEventListener(this, p), this);//we setup our listeners (If the player leaves or joins)
		//we pass in an instance of main and an instance of permissions (So we get all those nice permission methods)
		this.getCommand("core").setExecutor(new CommonCoreCommands(this,p));
	}
	public Permission Permission() {
		return p;
	}

	@Override
	public void onDisable() {
		this.saveConfig();
		this.getConfig();
		playerPermission.clear();
		System.out.println("Reloading the server");
		p.unloadPermissionsAndGroups();
	}
}

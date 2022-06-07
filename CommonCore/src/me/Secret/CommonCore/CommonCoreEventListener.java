package me.Secret.CommonCore;

import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.plugin.Plugin;

import me.Secret.CommonCore.Permissions.Permission;

public class CommonCoreEventListener implements Listener {
	
	private Plugin plugin;
	private Permission p;
	public CommonCoreEventListener(Plugin plugin, Permission p) {
		this.plugin = plugin;
		this.p = p;
	}
	@EventHandler
	public void onJoin(PlayerJoinEvent event) {
		Player player = event.getPlayer();
		p.setupPLayer(player);
	}
	@EventHandler
	public void onLeave(PlayerQuitEvent event) {
	}
	

}

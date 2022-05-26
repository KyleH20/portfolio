package me.Secret.CommonCore;

import java.util.List;

import org.bukkit.Bukkit;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.plugin.Plugin;

import me.Secret.CommonCore.Permissions.Groups;
import me.Secret.CommonCore.Permissions.Permission;

public class CommonCoreCommands implements CommandExecutor{
	private Permission p;
	private Plugin plugin;
	public CommonCoreCommands(Plugin plugin, Permission p) {
		this.p=p; this.plugin = plugin;//get an instance of main and permissions
	}

	@Override
	public boolean onCommand(CommandSender sender,  Command cmd, String label,String[] args) {
		if(label.equalsIgnoreCase("core")) {
			if(!sender.hasPermission("CommonCore.*")) {//if the player does not have all the permissions do nothing but send this message. Note: this is subject to change in the future
				sender.sendMessage(Util.convert("&CYou do not have permission to use this command")); return true;
			}
			if(args.length == 3) {
				if(args[0].equalsIgnoreCase("setgroup")) {
					for(Player onlinePlayers: Bukkit.getOnlinePlayers()){
						if(onlinePlayers.getName().equalsIgnoreCase(args[1])) {
							if(p.getGroup(onlinePlayers.getUniqueId()) !=null ) {
								//p.removePlayerFromGroup(onlinePlayers.getUniqueId());
							}
							if(p.getGroup(args[2]) !=null ) {
								if(!p.getGroup(args[2]).getPlayers().contains(onlinePlayers.getUniqueId())) {
									p.getGroup(args[2]).addPlayer(onlinePlayers.getUniqueId());
									p.setupPLayer(onlinePlayers);
									sender.sendMessage(Util.convert("&AYou have successfully added player &8"+onlinePlayers.getName()+"&A to the group &8"+p.getGroup(args[2]).getName()));
									onlinePlayers.sendMessage(Util.convert("&3&LCommonCore:&L&7 You are now in the group &8"+p.getGroup(args[2]).getName()));
									return true;
								}
								else {
									sender.sendMessage(Util.convert("&CThe player "+onlinePlayers.getName()+" is already in the group "+p.getGroup(args[2]).getName()));
									return true;
								}
								
							}
							else {
								sender.sendMessage(Util.convert("&CCould not find a group by that name"));
								return true;
							}
						}
					}
					sender.sendMessage(Util.convert("&CCould not find a player by that name"));
					return true;
				}
				else if(args[0].equalsIgnoreCase("removegroup")) {
					for(Player onlinePlayers: Bukkit.getOnlinePlayers()){
						if(onlinePlayers.getName().equalsIgnoreCase(args[1])) {
							Groups tempGroup = p.getGroup(args[2]);
							if(tempGroup != null) {
								if(tempGroup.containPlayer(onlinePlayers.getUniqueId())) {
									p.removePlayerFromGroup(onlinePlayers.getUniqueId(), tempGroup);
									sender.sendMessage(Util.convert("&AYou have successfully removed player &8"+onlinePlayers.getName()+"&A from Group &8"+tempGroup.getName()));
									onlinePlayers.sendMessage(Util.convert("&3&LCommonCore:&L&7 You are no longer in the group &8"+tempGroup.getName()));
									return true;
								}
								else {
									sender.sendMessage(Util.convert("&CPlayer &8"+onlinePlayers.getName()+" &CIs not in the group &8"+tempGroup.getName()));
									return true;
								}
							}
							else {
								sender.sendMessage(Util.convert("&CCould not find a group by that name"));
								return true;
							}
						}
					}
					sender.sendMessage(Util.convert("&CCould not find a player by that name"));
					return true;
				} 
				sender.sendMessage(Util.convert("&CSomething went wrong ): "));
				return true;
			}
			
			if(args.length == 2) {
				if(args[0].equalsIgnoreCase("getgroup")) {
					for(Player onlinePlayers: Bukkit.getOnlinePlayers()) {
						if(onlinePlayers.getName().equalsIgnoreCase(args[1])){
							List<Groups> tempGroups = p.getGroup(onlinePlayers.getUniqueId());
							if(tempGroups.size() == 0) {
								sender.sendMessage(Util.convert("&CThat player is not in a group"));
								return true;
							}
							String listOfGroups = "";
							for(Groups groups: tempGroups) {
								listOfGroups=listOfGroups+groups.getName()+" ";
							}
							sender.sendMessage(Util.convert("&7The player &8"+onlinePlayers.getName()+"&7 is in the group &8"+listOfGroups));
							return true;
						}
					}
					sender.sendMessage(Util.convert("&CCould not find a player by that name"));
					return true;
				}
				sender.sendMessage(Util.convert("&CWrong command!"));
			}
			if(args.length==1) {
				if(args[0].equalsIgnoreCase("getgroups")) {
					String groups ="";
					for(Groups group:p.getGroups()) {
						groups=groups+group.getName()+" ";
					}
					sender.sendMessage(Util.convert("&7"+groups));
				}
			}
			else {
				sender.sendMessage(Util.convert("&7You are currently running CommonCore version: &8"+Main.version));
				return true;
			}
		}
		return false;
	}

}

{ lib, ... }:

let
  containerUser = "agent-tools";
  containerId = 10001;
in
{
  virtualisation.vmVariant.dotfiles.scopes.serverApps.agentTools.enable = lib.mkForce false;

  # Agent Mail and ContextForge both use uid/gid 10001 in their upstream images.
  # Name that persistent host identity so userborn and tmpfiles preserve it by
  # service identity rather than scattering raw numeric ownership across apps.
  users.groups.${containerUser}.gid = containerId;
  users.users.${containerUser} = {
    isSystemUser = true;
    group = containerUser;
    uid = containerId;
  };

  agentMail = import ./agent-mail;
  chatgptSharedTools = import ./chatgpt-shared-tools;
  chatgptShellAccess = import ./chatgpt-shell-access;
  mcpGateway = import ./mcp-gateway;
}

{
  user,
  lib,
  ...
}: {
  users.users.${user.username} = {
    isNormalUser = lib.mkDefault true;
  };
}

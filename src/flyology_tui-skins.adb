package body Flyology_TUI.Skins is
   function Resolve (Id : Skin_Id) return Skin is
     (case Id is
         when Charm_Default => Charm_Default_Skin,
         when Charm_Dark    => Charm_Dark_Skin,
         when Charm_Light   => Charm_Light_Skin,
         when Turbo_Vision  => Turbo_Vision_Skin);

   function Next (Id : Skin_Id) return Skin_Id is
     (if Id = Skin_Id'Last then Skin_Id'First else Skin_Id'Succ (Id));

   function Label (Id : Skin_Id) return Wide_Wide_String is
     (case Id is
         when Charm_Default => "Charm",
         when Charm_Dark    => "Charm dark",
         when Charm_Light   => "Charm light",
         when Turbo_Vision  => "Turbo Vision");
end Flyology_TUI.Skins;

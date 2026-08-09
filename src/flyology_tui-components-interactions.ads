package Flyology_TUI.Components.Interactions is
   type Capture_Action is
     (No_Capture_Change,
      Acquire_Capture,
      Release_Capture);

   type Update_Result is record
      Handled         : Boolean := False;
      Focus_Requested : Boolean := False;
      Activated       : Boolean := False;
      Changed         : Boolean := False;
      Rejected        : Boolean := False;
      Capture         : Capture_Action := No_Capture_Change;
   end record;

   Ignored : constant Update_Result := (others => <>);
end Flyology_TUI.Components.Interactions;

package body Flyology_TUI.Events is

   function Pressed (Key : Key_Event) return Terminal_Event is
     (Kind => Key_Press, Key => Key);

   function Released (Key : Key_Event) return Terminal_Event is
     (Kind => Key_Release, Key => Key);

   function Resized (Width, Height : Natural) return Terminal_Event is
     (Kind => Resize, Width => Width, Height => Height);

end Flyology_TUI.Events;

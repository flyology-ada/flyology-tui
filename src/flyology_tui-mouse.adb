package body Flyology_TUI.Mouse is

   function Contains
     (Item : Region;
      X, Y : Natural) return Boolean
   is
     (X >= Item.X
      and then Y >= Item.Y
      and then X - Item.X < Item.Width
      and then Y - Item.Y < Item.Height);

   function Contains
     (Item  : Region;
      Event : Flyology_TUI.Events.Mouse_Event) return Boolean
   is (Contains (Item, Event.X, Event.Y));

   function Localize
     (Event : Flyology_TUI.Events.Mouse_Event;
      Item  : Region) return Flyology_TUI.Events.Mouse_Event
   is
      Result : Flyology_TUI.Events.Mouse_Event := Event;
   begin
      Result.X := Event.X - Item.X;
      Result.Y := Event.Y - Item.Y;
      return Result;
   end Localize;

   function Localize
     (Event : Flyology_TUI.Events.Terminal_Event;
      Item  : Region) return Flyology_TUI.Events.Terminal_Event
   is
     ((Kind  => Flyology_TUI.Events.Mouse_Input,
       Mouse => Localize (Event.Mouse, Item)));

end Flyology_TUI.Mouse;

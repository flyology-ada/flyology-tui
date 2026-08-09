package body Flyology_TUI.Mouse is

   function Saturating_Difference
     (Left, Right : Integer) return Integer
   is
   begin
      if Right > 0 and then Left < Integer'First + Right then
         return Integer'First;
      elsif Right < 0 and then Left > Integer'Last + Right then
         return Integer'Last;
      else
         return Left - Right;
      end if;
   end Saturating_Difference;

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

   function Relative
     (Event  : Flyology_TUI.Events.Mouse_Event;
      Origin : Flyology_TUI.Geometry.Point) return Local_Event
   is
     (X        => Saturating_Difference (Integer (Event.X), Origin.X),
      Y        => Saturating_Difference (Integer (Event.Y), Origin.Y),
      Button   => Event.Button,
      Action   => Event.Action,
      Modified => Event.Modified,
      Wheel_X  => Event.Wheel_X,
      Wheel_Y  => Event.Wheel_Y);

   function Relative
     (Event : Flyology_TUI.Events.Mouse_Event;
      Item  : Region) return Local_Event
   is (Relative
         (Event,
          Flyology_TUI.Geometry.Point'
            (X => Integer (Item.X), Y => Integer (Item.Y))));

   function Relative
     (Event  : Flyology_TUI.Events.Terminal_Event;
      Origin : Flyology_TUI.Geometry.Point) return Local_Event
   is (Relative (Event.Mouse, Origin));

end Flyology_TUI.Mouse;

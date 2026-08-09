with Flyology_TUI.Events;
with Flyology_TUI.Geometry;

package Flyology_TUI.Mouse is
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   type Region is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   --  Component-relative mouse data. Signed coordinates let a captured drag
   --  or release remain local after it leaves the component's current bounds.
   type Local_Event is record
      X          : Integer := 0;
      Y          : Integer := 0;
      Button     : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.No_Button;
      Action     : Flyology_TUI.Events.Mouse_Action :=
        Flyology_TUI.Events.Mouse_Move;
      Modified   : Flyology_TUI.Events.Modifiers;
      Wheel_X    : Integer := 0;
      Wheel_Y    : Integer := 0;
   end record;

   --  Return whether a terminal-cell coordinate lies inside Region.
   function Contains
     (Item : Region;
      X, Y : Natural) return Boolean;

   --  Return whether a mouse event lies inside Region.
   function Contains
     (Item  : Region;
      Event : Flyology_TUI.Events.Mouse_Event) return Boolean;

   --  Translate a mouse event from terminal coordinates to Region-relative
   --  coordinates. Modifiers, button state, action, and wheel deltas survive.
   function Localize
     (Event : Flyology_TUI.Events.Mouse_Event;
      Item  : Region) return Flyology_TUI.Events.Mouse_Event
     with Pre => Contains (Item, Event);

   --  Localize the mouse payload of a terminal event.
   function Localize
     (Event : Flyology_TUI.Events.Terminal_Event;
      Item  : Region) return Flyology_TUI.Events.Terminal_Event
     with Pre =>
       Event.Kind = Flyology_TUI.Events.Mouse_Input
       and then Contains (Item, Event.Mouse);

   --  Translate to signed coordinates relative to an arbitrary origin.
   --  Results saturate if the mathematical difference is outside Integer.
   function Relative
     (Event  : Flyology_TUI.Events.Mouse_Event;
      Origin : Flyology_TUI.Geometry.Point) return Local_Event;

   --  Relocalize an already-signed event for a nested or moving component.
   function Relative
     (Event  : Local_Event;
      Origin : Flyology_TUI.Geometry.Point) return Local_Event;

   function Relative
     (Event : Flyology_TUI.Events.Mouse_Event;
      Item  : Region) return Local_Event;

   function Relative
     (Event  : Flyology_TUI.Events.Terminal_Event;
      Origin : Flyology_TUI.Geometry.Point) return Local_Event
     with Pre => Event.Kind = Flyology_TUI.Events.Mouse_Input;
end Flyology_TUI.Mouse;

package body Flyology_TUI.Geometry is

   function Within
     (Value  : Integer;
      Origin : Integer;
      Extent : Natural) return Boolean
   is
   begin
      if Extent = 0 or else Value < Origin then
         return False;
      elsif Origin <= 0 then
         --  Adding a Natural to a nonpositive origin cannot overflow either
         --  Integer bound. This branch also avoids subtracting Integer'First.
         return Value < Origin + Integer (Extent);
      else
         --  Value and Origin are both positive, so their difference is
         --  representable even when Value is Integer'Last.
         return Value - Origin < Integer (Extent);
      end if;
   end Within;

   function Contains (Item : Rectangle; Value : Point) return Boolean is
     (Within (Value.X, Item.X, Item.Width)
      and then Within (Value.Y, Item.Y, Item.Height));

   function Contains
     (Item : Rectangle;
      X, Y : Integer) return Boolean
   is (Contains (Item, (X => X, Y => Y)));

end Flyology_TUI.Geometry;

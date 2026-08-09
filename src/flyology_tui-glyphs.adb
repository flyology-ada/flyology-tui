package body Flyology_TUI.Glyphs is

   function Code (Item : Wide_Wide_Character) return Natural is
     (Wide_Wide_Character'Pos (Item));

   function Is_Extender (Item : Wide_Wide_Character) return Boolean is
      C : constant Natural := Code (Item);
   begin
      return
        C in 16#0300# .. 16#036F#
        or else C in 16#1AB0# .. 16#1AFF#
        or else C in 16#1DC0# .. 16#1DFF#
        or else C in 16#20D0# .. 16#20FF#
        or else C in 16#FE00# .. 16#FE0F#
        or else C in 16#FE20# .. 16#FE2F#
        or else C in 16#1F3FB# .. 16#1F3FF#
        or else C in 16#E0100# .. 16#E01EF#
        or else C = 16#200D#;
   end Is_Extender;

   function Width_Of (Item : Wide_Wide_Character) return Cell_Width is
      C : constant Natural := Code (Item);
   begin
      if C = 0
        or else C < 32
        or else C in 16#7F# .. 16#9F#
        or else Is_Extender (Item)
      then
         return 0;
      elsif C in 16#1100# .. 16#115F#
        or else C in 16#2329# .. 16#232A#
        or else C in 16#2E80# .. 16#A4CF#
        or else C in 16#AC00# .. 16#D7A3#
        or else C in 16#F900# .. 16#FAFF#
        or else C in 16#FE10# .. 16#FE19#
        or else C in 16#FE30# .. 16#FE6F#
        or else C in 16#FF00# .. 16#FF60#
        or else C in 16#FFE0# .. 16#FFE6#
        or else C in 16#1F000# .. 16#1FAFF#
        or else C in 16#20000# .. 16#3FFFD#
      then
         return 2;
      else
         return 1;
      end if;
   end Width_Of;

   function Cluster_Last
     (Item  : Wide_Wide_String;
      First : Positive) return Natural
   is
      Last     : Natural := First;
      Join_Next : Boolean := False;
   begin
      while Last < Item'Last loop
         declare
            Next_Code : constant Natural := Code (Item (Last + 1));
         begin
            if Is_Extender (Item (Last + 1)) then
               Last := Last + 1;
               Join_Next := Next_Code = 16#200D#;
            elsif Join_Next then
               Last := Last + 1;
               Join_Next := False;
            else
               exit;
            end if;
         end;
      end loop;
      return Last;
   end Cluster_Last;

   function Width_Of (Item : Wide_Wide_String) return Natural is
      Result : Natural := 0;
      Pos    : Natural := Item'First;
   begin
      while Pos <= Item'Last loop
         declare
            Last : constant Natural := Cluster_Last (Item, Pos);
            Width : Cell_Width := Width_Of (Item (Pos));
         begin
            for Index in Pos + 1 .. Last loop
               Width := Cell_Width'Max (Width, Width_Of (Item (Index)));
            end loop;
            Result := Result + Width;
            Pos := Last + 1;
         end;
      end loop;
      return Result;
   end Width_Of;

end Flyology_TUI.Glyphs;

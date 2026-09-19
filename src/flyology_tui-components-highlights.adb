with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Highlights is

   function Style_At
     (Spans  : Span_Array;
      Offset : Natural;
      Base   : Flyology_TUI.Styles.Style)
      return Flyology_TUI.Styles.Style
   is
      Result : Flyology_TUI.Styles.Style := Base;
   begin
      for Index in Spans'Range loop
         if Offset >= Spans (Index).First
           and then Offset < Spans (Index).Last
         then
            Result := Spans (Index).Look;
         end if;
      end loop;
      return Result;
   end Style_At;

   function Is_Ordered (Spans : Span_Array) return Boolean is
      Previous : Natural := 0;
   begin
      for Index in Spans'Range loop
         if Spans (Index).First >= Spans (Index).Last
           or else Spans (Index).First < Previous
         then
            return False;
         end if;
         Previous := Spans (Index).Last;
      end loop;
      return True;
   end Is_Ordered;

   package body Lexers is

      Line_Feed : constant Wide_Wide_Character :=
        Wide_Wide_Character'Val (10);

      --  Return whether Offset is a grapheme-cluster boundary of Line. This
      --  mirrors the boundary rule Syntax_Editors applies to the same token
      --  contract, so a lexer accepted by one is accepted by the other.
      function Cluster_Boundary
        (Line : Wide_Wide_String; Offset : Natural) return Boolean
      is
         Position : Natural := 0;
      begin
         if Offset = 0 or else Offset = Line'Length then
            return True;
         end if;
         while Position < Line'Length loop
            if Position = Offset then
               return True;
            end if;
            Position :=
              Flyology_TUI.Glyphs.Cluster_Last
                (Line, Line'First + Position) - Line'First + 1;
         end loop;
         return False;
      end Cluster_Boundary;

      procedure Scan
        (Value  : Wide_Wide_String;
         Look   : Token_Appearance;
         Spans  : out Span_Array;
         Count  : out Natural;
         Status : out Scan_State)
      is
         Carried : Lexer_State := Initial_State;
         Base    : Natural := 0;
         Start   : Natural := Value'First;
         Stop    : Natural;
         Halted  : Boolean := False;

         --  Scan one line, appending spans rebased to Origin. Halted stays
         --  True once scanning must stop so the caller keeps the partial
         --  overlay already written.
         procedure Scan_Line
           (Line   : Wide_Wide_String;
            Origin : Natural)
         is
            Token_State : Lexer_State := Carried;
            Final       : Lexer_State := Carried;
            Scan_From   : Natural := 0;
            Kind        : Token_Kind;
            First, Last : Natural;
            Has_Token   : Boolean;
         begin
            loop
               Next_Token
                 (Line,
                  Token_State,
                  Scan_From,
                  Kind,
                  First,
                  Last,
                  Final,
                  Has_Token);
               exit when not Has_Token;
               if First < Scan_From
                 or else First >= Last
                 or else Last > Line'Length
                 or else not Cluster_Boundary (Line, First)
                 or else not Cluster_Boundary (Line, Last)
               then
                  Status := Scan_Structure_Invalid;
                  Halted := True;
                  return;
               elsif Count = Spans'Length then
                  Status := Scan_Capacity_Limited;
                  Halted := True;
                  return;
               end if;
               Count := Count + 1;
               Spans (Spans'First + Count - 1) :=
                 (First => Origin + First,
                  Last  => Origin + Last,
                  Look  => Look (Kind));
               Scan_From := Last;
               Token_State := Final;
            end loop;
            Carried := Final;
         exception
            when others =>
               Status := Scan_Lexer_Failed;
               Halted := True;
         end Scan_Line;

      begin
         Spans :=
           (others =>
              (First => 0,
               Last  => 0,
               Look  => Flyology_TUI.Styles.Default));
         Count := 0;
         Status := Scan_Complete;
         loop
            Stop := Start;
            while Stop <= Value'Last
              and then Value (Stop) /= Line_Feed
            loop
               Stop := Stop + 1;
            end loop;
            Scan_Line (Value (Start .. Stop - 1), Base);
            exit when Halted;
            exit when Stop > Value'Last;
            Base := Base + (Stop - Start) + 1;
            Start := Stop + 1;
         end loop;
      end Scan;

   end Lexers;

end Flyology_TUI.Components.Highlights;

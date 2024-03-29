{-
    BNF Converter: Java JLex generator
    Copyright (C) 2004  Author:  Michael Pellauer

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- 
   **************************************************************
    BNF Converter Module

    Description   : This module generates the JLex input file. This
                    file is quite different than Alex or Flex.

    Author        : Michael Pellauer (pellauer@cs.chalmers.se)

    License       : GPL (GNU General Public License)

    Created       : 25 April, 2003                           

    Modified      : 2 September, 2003                          

   
   ************************************************************** 
-}

module CFtoJLex ( cf2jlex ) where

import CF
import RegToJLex
import Utils		( (+++) )
import NamedVariables
import Data.List

--The environment must be returned for the parser to use.
cf2jlex :: String -> String -> CF -> (String, SymEnv)
cf2jlex packageBase packageAbsyn cf = (unlines $ concat $ 
 [
  prelude packageBase packageAbsyn,
  cMacros,
  lexSymbols env,
  restOfJLex cf
 ], env)
  where
   env = makeSymEnv (symbols cf ++ reservedWords cf) (0 :: Int)
   makeSymEnv [] _ = []
   makeSymEnv (s:symbs) n = (s, "_SYMB_" ++ (show n)) : (makeSymEnv symbs (n+1))
   
prelude :: String -> String -> [String]
prelude packageBase packageAbsyn =
    [
     "// This JLex file was machine-generated by the BNF converter",
     "package" +++ packageBase ++ ";",
     "",
     "import java_cup.runtime.*;",
     "import " ++ packageAbsyn ++ ".*;",
     "%%",
     "%cup",
     "%full",
     "%line",
     "%{",
     "  String pstring = new String();",
     "  public int line_num() { return (yyline+1); }",
     "  public String buff() { return new String(yy_buffer,yy_buffer_index,10).trim(); }",
     "%}"
    ]

--For now all categories are included.
--Optimally only the ones that are used should be generated.
cMacros :: [String]
cMacros = [
  "LETTER = ({CAPITAL}|{SMALL})",
  "CAPITAL = [A-Z\\xC0-\\xD6\\xD8-\\xDE]",
  "SMALL = [a-z\\xDF-\\xF6\\xF8-\\xFF]",
  "DIGIT = [0-9]",
  "IDENT = ({LETTER}|{DIGIT}|['_])",
  "%state COMMENT",
  "%state CHAR",
  "%state CHARESC",
  "%state CHAREND",
  "%state STRING",
  "%state ESCAPED",
  "%%"
  ]

lexSymbols :: SymEnv -> [String]
lexSymbols ss = map transSym ss
  where
    transSym (s,r) = 
      "<YYINITIAL>" ++ (escapeChars s) ++ " { return new Symbol(sym." 
      ++ r ++ "); }"

restOfJLex :: CF -> [String]
restOfJLex cf =
  [
   lexComments (comments cf),
   userDefTokens,
   ifC "String" strStates,
   ifC "Char" chStates,
   ifC "Double" "<YYINITIAL>{DIGIT}+\".\"{DIGIT}+(\"e\"(\\-)?{DIGIT}+)? { return new Symbol(sym._DOUBLE_, new Double(yytext())); }",
   ifC "Integer" "<YYINITIAL>{DIGIT}+ { return new Symbol(sym._INTEGER_, new Integer(yytext())); }",
    ifC "Ident" "<YYINITIAL>{LETTER}{IDENT}* { return new Symbol(sym._IDENT_, new String(yytext())); }"
   , "<YYINITIAL>[ \\t\\r\\n\\f] { /* ignore white space. */ }"
   ]
  where
   ifC cat s = if isUsedCat cf cat then s else ""
   userDefTokens = unlines $
     ["<YYINITIAL>" ++ printRegJLex exp +++ 
      "{ return new Symbol(sym." ++ name ++ ", yytext()); }"
       | (name, exp) <- tokenPragmas cf]
   strStates = unlines --These handle escaped characters in Strings.
    [
     "<YYINITIAL>\"\\\"\" { yybegin(STRING); }",
     "<STRING>\\\\ { yybegin(ESCAPED); }",
     "<STRING>\\\" { String foo = pstring; pstring = new String(); yybegin(YYINITIAL); return new Symbol(sym._STRING_, foo); }",
     "<STRING>.  { pstring += yytext(); }",
     "<ESCAPED>n { pstring +=  \"\\n\"; yybegin(STRING); }",
     "<ESCAPED>\\\" { pstring += \"\\\"\"; yybegin(STRING); }",
     "<ESCAPED>\\\\ { pstring += \"\\\\\"; yybegin(STRING); }",
     "<ESCAPED>t  { pstring += \"\\t\"; yybegin(STRING); }",
     "<ESCAPED>.  { pstring += yytext(); yybegin(STRING); }"
    ]
   chStates = unlines --These handle escaped characters in Chars.
    [
     "<YYINITIAL>\"'\" { yybegin(CHAR); }",
     "<CHAR>\\\\ { yybegin(CHARESC); }",
     "<CHAR>[^'] { yybegin(CHAREND); return new Symbol(sym._CHAR_, new Character(yytext().charAt(0))); }",
     "<CHARESC>n { yybegin(CHAREND); return new Symbol(sym._CHAR_, new Character('\\n')); }",
     "<CHARESC>t { yybegin(CHAREND); return new Symbol(sym._CHAR_, new Character('\\t')); }",
     "<CHARESC>. { yybegin(CHAREND); return new Symbol(sym._CHAR_, new Character(yytext().charAt(0))); }",
     "<CHAREND>\"'\" {yybegin(YYINITIAL);}"
    ]




lexComments :: ([(String, String)], [String]) -> String
lexComments (m,s) = 
  (unlines (map lexSingleComment s)) 
  ++ (unlines (map lexMultiComment m))

lexSingleComment :: String -> String
lexSingleComment c = 
  "<YYINITIAL>\"" ++ c ++ "\"[^\\n]*\\n { /* BNFC single-line comment */ }"

--There might be a possible bug here if a language includes 2 multi-line comments.
--They could possibly start a comment with one character and end it with another.
--However this seems rare.
lexMultiComment :: (String, String) -> String
lexMultiComment (b,e) = unlines [
  "<YYINITIAL>\"" ++ b ++ "\" { yybegin(COMMENT); }",
  "<COMMENT>\"" ++ e ++ "\" { yybegin(YYINITIAL); }",
  "<COMMENT>. { }",
  "<COMMENT>[\\n] { }"
  ]
  
-- lexReserved :: String -> String
-- lexReserved s = "<YYINITIAL>\"" ++ s ++ "\" { return new Symbol(sym.TS, yytext()); }"

--Helper function that escapes characters in strings
escapeChars :: String -> String
escapeChars = concatMap escapeChar

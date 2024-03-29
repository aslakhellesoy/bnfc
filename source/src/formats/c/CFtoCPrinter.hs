{-
    BNF Converter: C Pretty Printer printer
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

    Description   : This module generates the C Pretty Printer.
                    It also generates the "show" method for
                    printing an abstract syntax tree.
                    
                    The generated files use the Visitor design pattern.

    Author        : Michael Pellauer (pellauer@cs.chalmers.se)

    License       : GPL (GNU General Public License)

    Created       : 10 August, 2003                           

    Modified      : 3 September, 2003                          
                    * Added resizable buffers
   
   ************************************************************** 
-}

module CFtoCPrinter (cf2CPrinter) where

import CF
import Utils ((+++), (++++))
import NamedVariables
import Data.List
import Data.Char(toLower, toUpper)

--Produces (.h file, .c file)
cf2CPrinter :: CF -> (String, String)
cf2CPrinter cf = (mkHFile cf groups, mkCFile cf groups)
 where
    groups = (fixCoercions (ruleGroupsInternals cf))

{- **** Header (.h) File Methods **** -}

--An extremely large function to make the Header File
mkHFile :: CF -> [(Cat,[Rule])] -> String
mkHFile cf groups = unlines
 [
  header,
  concatMap prPrints eps,
  concatMap prPrintDataH groups,
  concatMap prShows eps,
  concatMap prShowDataH groups,
  footer
 ]
 where
  eps = allEntryPoints cf
  prPrints s | normCat s == s = "char* print" ++ s' ++ "(" ++ s' ++ " p);\n"
    where
      s' = identCat s
  prPrints _ = ""
  prShows s | normCat s == s = "char* show" ++ s' ++ "(" ++ s' ++ " p);\n"
    where
      s' = identCat s
  prShows _ = ""
  header = unlines
   [
    "#ifndef PRINTER_HEADER",
    "#define PRINTER_HEADER",
    "",
    "#include \"Absyn.h\"",
    "",
    "/* Certain applications may improve performance by changing the buffer size */",
    "#define BUFFER_INITIAL 2000",
    "/* You may wish to change _L_PAREN or _R_PAREN */",
    "#define _L_PAREN '('",
    "#define _R_PAREN ')'",
    "",
    "/* The following are simple heuristics for rendering terminals */",
    "/* You may wish to change them */",
    "void renderCC(Char c);",
    "void renderCS(String s);",
    "void indent(void);",
    "void backup(void);",
    ""
   ]
  footer = unlines $
   ["void pp" ++ t ++ "(String s, int i);" | t <- tokenNames cf]
    ++
   ["void sh" ++ t ++ "(String s);" | t <- tokenNames cf]
    ++
   [
    "void ppInteger(Integer n, int i);",
    "void ppDouble(Double d, int i);",
    "void ppChar(Char c, int i);",
    "void ppString(String s, int i);",
    "void ppIdent(String s, int i);",
    "void shInteger(Integer n);",
    "void shDouble(Double d);",
    "void shChar(Char c);",
    "void shString(String s);",
    "void shIdent(String s);",
    "void bufAppendS(const char* s);",
    "void bufAppendC(const char c);",
    "void bufReset(void);",
    "void resizeBuffer(void);",
    "",
    "#endif"
   ]

--Prints all the required method names and their parameters.
prPrintDataH :: (Cat, [Rule]) -> String
prPrintDataH (cat, rules) = concat ["void pp", cl, "(", cl, " p, int i);\n"]
  where
   cl = identCat (normCat cat)
  
--Prints all the required method names and their parameters.
prShowDataH :: (Cat, [Rule]) -> String
prShowDataH (cat, rules) = concat ["void sh", cl, "(", cl, " p);\n"]
  where
   cl = identCat (normCat cat)

{- **** Implementation (.C) File Methods **** -}

--This makes the .C file by a similar method.
mkCFile :: CF -> [(Cat,[Rule])] -> String
mkCFile cf groups = concat 
   [
    header,
    prRender,
    concatMap prPrintFun eps,
    concatMap prShowFun eps,
    concatMap (prPrintData user) groups,
    printBasics,
    printTokens,
    concatMap (prShowData user) groups,
    showBasics,
    showTokens,
    footer
   ]
  where
    eps = allEntryPoints cf
    user = fst (unzip (tokenPragmas cf))
    header = unlines 
     [
      "/*** BNFC-Generated Pretty Printer and Abstract Syntax Viewer ***/",
      "",
      "#include \"Printer.h\"",
      "#include <stdio.h>",
      "#include <string.h>",
      "#include <stdlib.h>",
      "",
      "int _n_;",
      "char* buf_;",
      "int cur_;",
      "int buf_size;",
      ""
     ]
    printBasics = unlines 
     [
      "void ppInteger(Integer n, int i)",
      "{",
      "  char tmp[16];",
      "  sprintf(tmp, \"%d\", n);",
      "  bufAppendS(tmp);",
      "}",
      "void ppDouble(Double d, int i)",
      "{",
      "  char tmp[16];",
      "  sprintf(tmp, \"%g\", d);",
      "  bufAppendS(tmp);",
      "}",
      "void ppChar(Char c, int i)",
      "{",
      "  bufAppendC('\\'');",
      "  bufAppendC(c);",
      "  bufAppendC('\\'');",
      "}",
      "void ppString(String s, int i)",
      "{",
      "  bufAppendC('\\\"');",
      "  bufAppendS(s);",
      "  bufAppendC('\\\"');",
      "}",
      "void ppIdent(String s, int i)",
      "{",
      "  renderS(s);",
      "}",
      ""
     ]
    printTokens = unlines 
     [unlines [
      "void pp" ++ t ++ "(String s, int i)",
      "{",
      "  renderS(s);",
      "}",
      ""
      ] | t <- tokenNames cf
     ]
    showBasics = unlines 
     [
      "void shInteger(Integer i)",
      "{",
      "  char tmp[16];",
      "  sprintf(tmp, \"%d\", i);",
      "  bufAppendS(tmp);",
      "}",
      "void shDouble(Double d)",
      "{",
      "  char tmp[16];",
      "  sprintf(tmp, \"%g\", d);",
      "  bufAppendS(tmp);",
      "}",
      "void shChar(Char c)",
      "{",
      "  bufAppendC('\\'');",
      "  bufAppendC(c);",
      "  bufAppendC('\\'');",
      "}",
      "void shString(String s)",
      "{",
      "  bufAppendC('\\\"');",
      "  bufAppendS(s);",
      "  bufAppendC('\\\"');",
      "}",
      "void shIdent(String s)",
      "{",
      "  bufAppendC('\\\"');",
      "  bufAppendS(s);",
      "  bufAppendC('\\\"');",
      "}",
      ""
     ]
    showTokens = unlines 
     [unlines [
      "void sh" ++ t ++ "(String s)",
      "{",
      "  bufAppendC('\\\"');",
      "  bufAppendS(s);",
      "  bufAppendC('\\\"');",
      "}",
      ""
      ] | t <- tokenNames cf
     ]
    footer = unlines
     [
      "void bufAppendS(const char* s)",
      "{",
      "  int len = strlen(s);",
      "  int n;",
      "  while (cur_ + len > buf_size)",
      "  {",
      "    buf_size *= 2; /* Double the buffer size */",
      "    resizeBuffer();",
      "  }",
      "  for(n = 0; n < len; n++)",
      "  {",
      "    buf_[cur_ + n] = s[n];",
      "  }",
      "  cur_ += len;",
      "  buf_[cur_] = 0;",
      "}",
      "void bufAppendC(const char c)",
      "{",
      "  if (cur_ == buf_size)",
      "  {",
      "    buf_size *= 2; /* Double the buffer size */",
      "    resizeBuffer();",
      "  }",
      "  buf_[cur_] = c;",
      "  cur_++;",
      "  buf_[cur_] = 0;",
      "}",
      "void bufReset(void)",
      "{",
      "  cur_ = 0;",
      "  buf_size = BUFFER_INITIAL;",
      "  resizeBuffer();",
      "  memset(buf_, 0, buf_size);",
      "}",
      "void resizeBuffer(void)",
      "{",
      "  char* temp = (char*) malloc(buf_size);",
      "  if (!temp)",
      "  {",
      "    fprintf(stderr, \"Error: Out of memory while attempting to grow buffer!\\n\");",
      "    exit(1);",
      "  }",
      "  if (buf_)",
      "  {",
      "    strncpy(temp, buf_, buf_size); /* peteg: strlcpy is safer, but not POSIX/ISO C. */",
      "    free(buf_);",
      "  }",
      "  buf_ = temp;",
      "}",
      "char *buf_;",
      "int cur_, buf_size;",
      ""
     ]
    

{- **** Pretty Printer Methods **** -}

--An entry point to begin printing
prPrintFun :: Cat -> String
prPrintFun ep | normCat ep == ep = unlines
  [
   "char* print" ++ ep' ++ "(" ++ ep' ++ " p)",
   "{",
   "  _n_ = 0;",
   "  bufReset();",
   "  pp" ++ ep' ++ "(p, 0);",
   "  return buf_;",
   "}"
  ]
 where
  ep' = identCat ep
prPrintFun _ = ""

--Generates methods for the Pretty Printer
prPrintData :: [UserDef] -> (Cat, [Rule]) -> String
prPrintData user (cat, rules) = 
 if isList cat
 then unlines
 [
  "void pp" ++ cl ++ "("++ cl +++ vname ++ ", int i)",
  "{",
  "  while(" ++ vname ++ "!= 0)",
  "  {",
  "    if (" ++ vname ++ "->" ++ vname ++ "_ == 0)",
  "    {",
  visitMember,
  optsep,
  "      " ++ vname +++ "= 0;",
  "    }",
  "    else",
  "    {",
  visitMember,
  "      render" ++ sc ++ "(" ++ sep ++ ");",
  "      " ++ vname +++ "=" +++ vname ++ "->" ++ vname ++ "_;",
  "    }",
  "  }",
  "}",
  ""
 ] --Not a list:
 else unlines
 [
   "void pp" ++ cl ++ "(" ++ cl ++ " _p_, int _i_)",
   "{",
   "  switch(_p_->kind)",
   "  {",
   concatMap (prPrintRule user) rules,
   "  default:",
   "    fprintf(stderr, \"Error: bad kind field when printing " ++ cat ++ "!\\n\");",
   "    exit(1);",
   "  }",
   "}\n"
 ]
 where
   cl = identCat (normCat cat)
   ecl = identCat (normCatOfList cat)
   vname = map toLower cl
   member = map toLower ecl
   visitMember = "      pp" ++ ecl ++ "(" ++ vname ++ "->" ++ member ++ "_, 0);"
   (sc, sep) = if length sep' == 1
     then ("C", "'" ++ escapeChars sep' ++ "'")
     else ("S", "\"" ++ escapeChars sep' ++ "\"")
   sep' = getCons rules
   optsep = if hasOneFunc rules then "" else ("      render" ++ sc ++ "(" ++ sep ++ ");")
    
--Pretty Printer methods for a rule.
prPrintRule :: [UserDef] -> Rule -> String
prPrintRule user r@(Rule (fun, (c, cats))) | not (isCoercion fun) = unlines
  [
   "  case is_" ++ fun ++ ":",
   lparen,
   cats',
   rparen,
   "    break;\n"
  ]
   where
    p = precRule r
    (lparen, rparen) = 
      ("    if (_i_ > " ++ (show p) ++ ") renderC(_L_PAREN);",
       "    if (_i_ > " ++ (show p) ++ ") renderC(_R_PAREN);")
    cats' = (concatMap (prPrintCat user fun) (zip3 (fixOnes (numVars [] cats)) cats (map getPrec cats)))
    getPrec (Right s) = (0 :: Int)
    getPrec (Left c) = precCat c
prPrintRule _ _ = ""

--This goes on to recurse to the instance variables.
prPrintCat :: [UserDef] -> String -> (Either Cat String, Either Cat String, Int) -> String
prPrintCat user fnm (c,o,p) = case c of
  (Right t) -> "    render" ++ sc ++ "(" ++ t' ++ ");\n"
    where
     (sc,t') = if length t == 1
       then ("C", "'" ++ (escapeChars t) ++ "'")
       else ("S", "\"" ++ (escapeChars t) ++ "\"")
  (Left nt) -> if isBasic user nt
       then "    pp" ++ (basicFunName nt) ++ "(_p_->u." ++ v ++ "_." ++ nt ++ ", " ++ (show p) ++ ");\n"
       else if nt == "#_" --Internal category
         then "    /* Internal Category */\n"
         else "    pp" ++ o' ++ "(_p_->u." ++ v ++ "_." ++ nt ++ ", " ++ (show p) ++ ");\n"
 where
  v = map toLower (identCat (normCat fnm))
  o' = case o of
    Right x -> x
    Left x -> normCat (identCat x)        

{- **** Abstract Syntax Tree Printer **** -}

--An entry point to begin printing
prShowFun :: Cat -> String
prShowFun ep | normCat ep == ep = unlines
  [
   "char* show" ++ ep' ++ "(" ++ ep' ++ " p)",
   "{",
   "  _n_ = 0;",
   "  bufReset();",
   "  sh" ++ ep' ++ "(p);",
   "  return buf_;",
   "}"
  ]
 where
  ep' = identCat ep
prShowFun _ = ""
  
--This prints the functions for Abstract Syntax tree printing.
prShowData :: [UserDef] -> (Cat, [Rule]) -> String
prShowData user (cat, rules) = 
 if isList cat
 then unlines
 [
  "void sh" ++ cl ++ "("++ cl +++ vname ++ ")",
  "{",
  "  while(" ++ vname ++ "!= 0)",
  "  {",
  "    if (" ++ vname ++ "->" ++ vname ++ "_)",
  "    {",
  visitMember,
  "      bufAppendS(\", \");",
  "      " ++ vname +++ "=" +++ vname ++ "->" ++ vname ++ "_;",
  "    }",
  "    else",
  "    {",
  visitMember,
  "      " ++ vname ++ " = 0;",
  "    }",
  "  }",
  "}",
  ""
 ] --Not a list:
 else unlines
 [
   "void sh" ++ cl ++ "(" ++ cl ++ " _p_)",
   "{",
   "  switch(_p_->kind)",
   "  {",
   concatMap (prShowRule user) rules,
   "  default:",
   "    fprintf(stderr, \"Error: bad kind field when showing " ++ cat ++ "!\\n\");",
   "    exit(1);",
   "  }",
   "}\n"
 ]
 where
   cl = identCat (normCat cat)
   ecl = identCat (normCatOfList cat)
   vname = map toLower cl
   member = map toLower ecl
   visitMember = "      sh" ++ ecl ++ "(" ++ vname ++ "->" ++ member ++ "_);"
    
--Pretty Printer methods for a rule.
prShowRule :: [UserDef] -> Rule -> String
prShowRule user r@(Rule (fun, (c, cats))) | not (isCoercion fun) = unlines
  [
   "  case is_" ++ fun ++ ":",
   lparen,
   "    bufAppendS(\"" ++ fun ++ "\");\n",
   optspace,
   cats',
   rparen,
   "    break;\n"
  ]
   where
    (optspace, lparen, rparen) = if allTerms cats
      then ("","","")
      else ("  bufAppendC(' ');\n", "  bufAppendC('(');\n","  bufAppendC(')');\n")
    cats' = if allTerms cats
        then ""
    	else concat (insertSpaces (map (prShowCat user fun) (zip (fixOnes (numVars [] cats)) cats)))
    insertSpaces [] = []
    insertSpaces (x:[]) = [x]
    insertSpaces (x:xs) = if x == "" 
      then insertSpaces xs
      else (x : ["  bufAppendC(' ');\n"]) ++ (insertSpaces xs)
    allTerms [] = True
    allTerms ((Left z):zs) = False
    allTerms (z:zs) = allTerms zs
prShowRule _ _ = ""

--This goes on to recurse to the instance variables.
prShowCat :: [UserDef] -> String -> (Either Cat String, Either Cat String) -> String
prShowCat user fnm (c,o) = case c of
  (Right t) -> ""
  (Left nt) -> if isBasic user nt
       then "    sh" ++ (basicFunName nt) ++ "(_p_->u." ++ v ++ "_." ++ nt ++ ");\n"
       else if nt == "#_" --Internal category
         then "    /* Internal Category */\n"
         else if ((normCat nt) /= nt)
          then "    sh" ++ o' ++ "(_p_->u." ++ v ++ "_." ++ nt ++ ");\n"
          else concat
          [
	   "    bufAppendC('[');\n",
           "    sh" ++ o' ++ "(_p_->u." ++ v ++ "_." ++ nt ++ ");\n",
	   "    bufAppendC(']');\n"
          ]
 where
  v = map toLower (identCat (normCat fnm))
  o' = case o of
    Right x -> x
    Left x -> normCat (identCat x)    

{- **** Helper Functions Section **** -}


--Just checks if something is a basic or user-defined type.
--This is because you don't -> a basic non-pointer type.
isBasic :: [UserDef] -> String -> Bool
isBasic user v = 
  if elem (init v) user'
    then True
    else if "integer_" `isPrefixOf` v then True
    else if "char_" `isPrefixOf` v then True
    else if "string_" `isPrefixOf` v then True
    else if "double_" `isPrefixOf` v then True
    else if "ident_" `isPrefixOf` v then True
    else False
  where
   user' = map (map toLower) user

--The visit-function name of a basic type
basicFunName :: String -> String
basicFunName v = 
    if "integer_" `isPrefixOf` v then "Integer"
    else if "char_" `isPrefixOf` v then "Char"
    else if "string_" `isPrefixOf` v then "String"
    else if "double_" `isPrefixOf` v then "Double"
    else if "ident_" `isPrefixOf` v then "Ident"
    else "Ident" --User-defined type

--Just sets the coercion level for parentheses in the Pretty Printer.
setI :: Int -> String
setI n = "_i_ = " ++ (show n) ++ "; "

--Gets the separator for a list.
getCons :: [Rule] -> String
getCons [] = error $ "FIXME: CFtoCPrinter/getCons: No separator for a list."
getCons (Rule (f, (c, cats)):rs) =
 if isConsFun f
   then seper cats
   else getCons rs
 where
    seper [] = []
    seper ((Right x):xs) = x
    seper ((Left x):xs) = seper xs

--Checks if the list has a non-empty rule.
hasOneFunc :: [Rule] -> Bool
hasOneFunc [] = False
hasOneFunc (Rule (f, (c, cats)):rs) =
 if (isOneFun f)
    then True
    else hasOneFunc rs
    
--Helper function that escapes characters in strings
escapeChars :: String -> String
escapeChars [] = []
escapeChars ('\\':xs) = '\\' : ('\\' : (escapeChars xs))
escapeChars ('\"':xs) = '\\' : ('\"' : (escapeChars xs))
escapeChars (x:xs) = x : (escapeChars xs)
    
--An extremely simple renderCer for terminals.
prRender :: String
prRender = unlines
  [
      "/* You may wish to change the renderC functions */",
      "void renderC(Char c)",
      "{",
      "  if (c == '{')",
      "  {",
      "     bufAppendC('\\n');",
      "     indent();",
      "     bufAppendC(c);",
      "     _n_ = _n_ + 2;",
      "     bufAppendC('\\n');",
      "     indent();",
      "  }",
      "  else if (c == '(' || c == '[')",
      "     bufAppendC(c);",
      "  else if (c == ')' || c == ']')",
      "  {",
      "     backup();",
      "     bufAppendC(c);",
      "     bufAppendC(' ');",
      "  }",
      "  else if (c == '}')",
      "  {",
      "     _n_ = _n_ - 2;",
      "     backup();",
      "     backup();",
      "     bufAppendC(c);",
      "     bufAppendC('\\n\');",
      "     indent();",
      "  }",
      "  else if (c == ',')",
      "  {",
      "     backup();",
      "     bufAppendC(c);",
      "     bufAppendC(' ');",
      "  }",
      "  else if (c == ';')",
      "  {",
      "     backup();",
      "     bufAppendC(c);",
      "     bufAppendC('\\n');",
      "     indent();",
      "  }",
      "  else if (c == 0) return;",
      "  else",
      "  {",
      "     bufAppendC(c);",
      "     bufAppendC(' ');",
      "  }",
      "}",
      "void renderS(String s)",
      "{",
      "  if(strlen(s) > 0)",
      "  {",
      "    bufAppendS(s);",
      "    bufAppendC(' ');",
      "  }",
      "}",
      "void indent(void)",
      "{",
      "  int n = _n_;",
      "  while (n > 0)",
      "  {",
      "    bufAppendC(' ');",
      "    n--;",
      "  }",
      "}",
      "void backup(void)",
      "{",
      "  if (buf_[cur_ - 1] == ' ')",
      "  {", 
      "    buf_[cur_ - 1] = 0;",
      "    cur_--;",
      "  }",
      "}"
  ]

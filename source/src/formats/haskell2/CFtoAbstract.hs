{-
    BNF Converter: Abstract syntax Generator
    Copyright (C) 2004  Author:  Markus Forberg

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

module CFtoAbstract (cf2Abstract) where

import CF
import Utils((+++),(++++))
import Data.List(intersperse)

-- to produce a Haskell module
cf2Abstract :: Bool -> String -> CF -> String
cf2Abstract byteStrings name cf = unlines $ 
  ("module "++name +++ "where\n") :
  "-- Haskell module generated by the BNF converter\n" :
  (if byteStrings then "import qualified Data.ByteString.Char8 as BS" else "") :
  (map (prSpecialData byteStrings cf) (specialCats cf) ++ map prData (cf2data cf))

prData :: Data -> String
prData (cat,rules) = 
  "data" +++ cat +++ "=\n   " ++
  concat (intersperse "\n | " (map prRule rules)) ++++
  "  deriving (Eq,Ord,Show)\n"
 where
   prRule (fun,cats) = unwords (fun:cats)

prSpecialData :: Bool -> CF -> Cat -> String
prSpecialData byteStrings cf cat = 
  unwords ["newtype",cat,"=",cat,contentSpec byteStrings cf cat,"deriving (Eq,Ord,Show)"]

contentSpec :: Bool -> CF -> Cat -> String
contentSpec byteStrings cf cat = if isPositionCat cf cat then "((Int,Int),"++stringType++")" else stringType
  where
    stringType
      | byteStrings = "BS.ByteString"
      | otherwise   = "String"
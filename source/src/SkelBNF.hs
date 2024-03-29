module SkelBNF where

-- Haskell module generated by the BNF converter

import AbsBNF
import ErrM
type Result = Err String

failure :: Show a => a -> Result
failure x = Bad $ "Undefined case: " ++ show x

transIdent :: Ident -> Result
transIdent x = case x of
  Ident str  -> failure x


transLGrammar :: LGrammar -> Result
transLGrammar x = case x of
  LGr ldefs  -> failure x


transLDef :: LDef -> Result
transLDef x = case x of
  DefAll def  -> failure x
  DefSome ids def  -> failure x
  LDefView ids  -> failure x


transGrammar :: Grammar -> Result
transGrammar x = case x of
  Grammar defs  -> failure x


transDef :: Def -> Result
transDef x = case x of
  Rule label cat items  -> failure x
  Comment str  -> failure x
  Comments str1 str2  -> failure x
  Internal label cat items  -> failure x
  Token id reg  -> failure x
  PosToken id reg  -> failure x
  Entryp ids  -> failure x
  Separator minimumsize cat str  -> failure x
  Terminator minimumsize cat str  -> failure x
  Coercions id n  -> failure x
  Rules id rhss  -> failure x
  Function id args exp  -> failure x
  Layout strs  -> failure x
  LayoutStop strs  -> failure x
  LayoutTop  -> failure x


transItem :: Item -> Result
transItem x = case x of
  Terminal str  -> failure x
  NTerminal cat  -> failure x


transCat :: Cat -> Result
transCat x = case x of
  ListCat cat  -> failure x
  IdCat id  -> failure x


transLabel :: Label -> Result
transLabel x = case x of
  LabNoP labelid  -> failure x
  LabP labelid profitems  -> failure x
  LabPF labelid1 labelid2 profitems3  -> failure x
  LabF labelid1 labelid2  -> failure x


transLabelId :: LabelId -> Result
transLabelId x = case x of
  Id id  -> failure x
  Wild  -> failure x
  ListE  -> failure x
  ListCons  -> failure x
  ListOne  -> failure x


transProfItem :: ProfItem -> Result
transProfItem x = case x of
  ProfIt intlists ns  -> failure x


transIntList :: IntList -> Result
transIntList x = case x of
  Ints ns  -> failure x


transArg :: Arg -> Result
transArg x = case x of
  Arg id  -> failure x


transExp :: Exp -> Result
transExp x = case x of
  Cons exp1 exp2  -> failure x
  App id exps  -> failure x
  Var id  -> failure x
  LitInt n  -> failure x
  LitChar c  -> failure x
  LitString str  -> failure x
  LitDouble d  -> failure x
  List exps  -> failure x


transRHS :: RHS -> Result
transRHS x = case x of
  RHS items  -> failure x


transMinimumSize :: MinimumSize -> Result
transMinimumSize x = case x of
  MNonempty  -> failure x
  MEmpty  -> failure x


transReg :: Reg -> Result
transReg x = case x of
  RSeq reg1 reg2  -> failure x
  RAlt reg1 reg2  -> failure x
  RMinus reg1 reg2  -> failure x
  RStar reg  -> failure x
  RPlus reg  -> failure x
  ROpt reg  -> failure x
  REps  -> failure x
  RChar c  -> failure x
  RAlts str  -> failure x
  RSeqs str  -> failure x
  RDigit  -> failure x
  RLetter  -> failure x
  RUpper  -> failure x
  RLower  -> failure x
  RAny  -> failure x




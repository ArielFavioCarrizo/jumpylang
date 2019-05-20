-- |
-- Module      :  Esferixis.Jumpy.AST
-- Copyright   :  (c) 2019 Ariel Favio Carrizo
-- License     :  BSD-3-Clause
-- Stability   : experimental
-- Portability : ghc

{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE GADTs #-}

module Esferixis.Jumpy.Asg where

import Text.Show
import Data.Word
import Data.Maybe
import Data.Either
import Data.Int

class (Show ni) => JLocInfo ni

data TaggedNode ni a = TaggedNode ni a

data ModuleId x = ModuleId Int
data TypeClassId x = TypeClassId Int
data StructId x = StructId x
data UnionId x = UnionId x
data StructMemberId x = StructMemberId x
data UnionMemberId x = UnionMemberId x
data FunId x = FunId Int
data StateId x = StateId Int
data VarId x = VarId Int
data LabelId x = LabelId Int

data Entity x = 
   ModuleEntity (ModuleId x) |
   TypeClassEntity (TypeClassId x) |
   StructEntity (StructId x) |
   UnionEntity (UnionId x) |
   StructMemberEntity (StructMemberId x) |
   UnionMemberEntity (UnionMemberId x) |
   FunEntity (FunId x) |
   StateEntity (StateId x) |
   VarEntity (VarId x) |
   LabelEntity (LabelId x)

data LinkageType =
   PrivateLinkage |
   InternalLinkage |
   ExternalLinkage

data MemberAccess =
   PublicMember |
   PrivateMember
   
data ExprDecl ni e o = ExprDecl ni e o
data ExprId x = ExprId x

data TypeExprDecl ni e o = TypeExprDecl ni e o
data TypeExprId x = TypeExprId x

data EntityName = GlobalEntityName String | LocalEntityName String

data FunDeclException x =
   EntityExistsFunDeclException (Entity x) |
   FunSignatureMismatch (FunId x)
   
data StateDeclException x =
   EntityExistsStateDeclException (Entity x) |
   StateTypeMismatch (StateId x)
   
data VarDeclException x =
   EntityExistsVarDeclException (Entity x)
   
data StructDeclException x =
   EntityExistsStructDeclException (Entity x)
  
data UnionDeclException x =
   EntityExistsUnionDeclException (Entity x)
   
data LinkageException x =
   LinkageHasBeenDeclared (FunId x)
   
data LinkedDeclException x =
   JustLinkageException (LinkageException x) |
   OtherException x
   
data EntityNotFoundException = EntityNotFoundException EntityName

data DeclCmd cmd ni e o = DeclCmd ( forall x. Asg x ni ( cmd x ni ) e (ni, o) ) -- It is rank-2 type because local declarations are only valid in this scope

data ModuleMemberDecl x ni e o where
   ModuleFunDecl :: Maybe (TaggedNode ni LinkageType) -> FunDecl x -> ModuleMemberDecl x ni ( LinkedDeclException ( FunDeclException x ) ) ()
   ModuleStateDecl :: Maybe (TaggedNode ni LinkageType) -> StateDecl x -> ModuleMemberDecl x ni ( LinkedDeclException ( StateDeclException x ) ) ()
   ModuleStructDecl :: StructDecl ni e o -> ModuleMemberDecl x ni ( Either (StructDeclException x) e ) o
   ModuleUnionDecl :: UnionDecl ni e o -> ModuleMemberDecl x ni ( Either (StructDeclException x) e ) o

data ModuleCmd x ni e o where
   ModuleCmdMemberDecl :: (TaggedNode ni MemberAccess) -> ModuleMemberDecl x ni e o -> ModuleCmd x ni e o

data StructMemberDeclException x =
   StructMemberExistsException (StructMemberId x)

data StructCmd x ni e o where
   StructMemberDecl :: ni -> TypeExprId x -> String -> StructCmd x ni (StructMemberDeclException x) ()
   
type StructDecl ni e o = DeclCmd StructCmd ni e o
   
data UnionMemberDeclException x =
   UnionMemberExistsException (UnionMemberId x)
   
data UnionCmd x ni e o where
   UnionMemberDecl :: ni -> TypeExprId x -> UnionCmd x ni (UnionMemberDeclException x) ()
   
type UnionDecl ni e o = DeclCmd UnionCmd ni e o

data LabelDeclException x =
   LabelExistsException (LabelId x)
   
data InstrScopeId x = InstrScopeId x
type InstrScopeDecl ni e o = DeclCmd InstrScopeCmd ni e o

data InstrScopeCmd x ni e o where
   InstrScopeExprDecl :: ExprDecl ni e o -> InstrScopeCmd x ni e (ExprId x, o)
   InstrScopeInstrScopeDecl :: InstrScopeDecl ni e o -> InstrScopeCmd x ni e (InstrScopeId x)
   InstrScopeFunDecl :: FunDecl x -> InstrScopeCmd x ni (FunDeclException x) ()
   InstrScopeStateDecl :: StateDecl x -> InstrScopeCmd x ni (StateDeclException x) ()
   InstrScopeVarDecl :: VarDecl x -> InstrScopeCmd x ni (VarDeclException x) ()
   InstrScopeStructDecl :: StructDecl ni e o -> InstrScopeCmd x ni ( Either (StructDeclException x) e ) o
   InstrScopeUnionDecl :: UnionDecl ni e o -> InstrScopeCmd x ni ( Either (UnionDeclException x) e ) o
   InstrScopeLabelDecl :: TaggedNode ni String -> InstrScopeCmd x ni (LabelDeclException x) ()
   InstrScopeIfDecl :: ni -> [((ExprId x), (InstrScopeId x))] -> Maybe (ExprId x) -> InstrScopeCmd x ni e ()
   InstrScopeWhileDecl :: ni -> ExprId x -> InstrScopeId x -> InstrScopeCmd x ni e ()
   InstrScopeDoWhileDecl :: ni -> InstrScopeId x -> ExprId x -> InstrScopeCmd x ni e ()
   InstrScopeBreakDecl :: ni -> InstrScopeCmd x ni e ()
   InstrScopeContinueDecl :: ni -> InstrScopeCmd x ni e ()
   InstrScopeReturnDecl :: ni -> Maybe (ExprId x) -> InstrScopeCmd x ni e ()
   InstrScopeGoToDecl :: ExprId x -> InstrScopeCmd x ni e ()

data ModuleDecl x ni e o = ModuleDecl (TaggedNode ni String) ( Asg x ni (ModuleCmd x ni) e o)

data CallingConv = CDeclCallingConv | StdCallCallingConv
data StateConv = CDeclStateConv

data FunDecl x = FunDecl [FunArg x] ( Maybe (InstrScopeId x) )
data FunArg x = FunArg (TypeExprId x) String

data StateDecl x = StateDecl (StateContextDecl x) ( Maybe (InstrScopeId x) )
data StateContextDecl x = AnonymusStateContextDecl (TypeExprId x) | NamedStateContextDecl (TypeExprId x) String

data VarDecl x = VarDecl (TypeExprId x) String

data Asg x ni cmd e o where
   AsgFindEntityByName :: EntityName -> Asg x ni cmd EntityNotFoundException (Entity x)
   AsgTypeExprDecl :: TypeExprDecl ni e o -> Asg x ni cmd e (TypeExprId x, o)
   AsgThrow :: e -> Asg x ni cmd e o
   AsgTry :: Asg x ni cmd e o -> Asg x ni cmd e2 (Either e o)
   AsgExecuteCommand :: cmd e o -> Asg x ni cmd e o
   AsgBind :: Asg x ni cmd e i -> ( i -> Asg x ni cmd e o ) -> Asg x ni cmd e o
   AsgReturn :: o -> Asg x ni cmd e o

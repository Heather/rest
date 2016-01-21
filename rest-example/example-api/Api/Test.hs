{-# LANGUAGE
    DeriveDataTypeable
  , DeriveGeneric
  , LambdaCase
  , OverloadedStrings
  , ScopedTypeVariables
  #-}
module Api.Test
  ( resource
  , WithText
  , Err (..)
  , Ok (..)
  ) where

import Control.Monad.Error.Class
import Control.Monad.Reader
import Data.Aeson
import Data.Data
import Data.JSON.Schema
import Data.Text (Text)
import GHC.Generics
import Generics.Generic.Aeson
import Generics.XmlPickler
import Text.XML.HXT.Arrow.Pickle

import Rest
import qualified Rest.Resource as R

import ApiTypes
import qualified Api.Test.Err2 as E2

-- | User extends the root of the API with a reader containing the ways to identify a user in our URLs.
-- Currently only by the user name.
type WithText = ReaderT Text BlogApi

data Err = Err deriving (Generic, Show, Typeable)
instance ToJSON     Err where toJSON    = gtoJson
instance FromJSON   Err where parseJSON = gparseJson
instance JSONSchema Err where schema    = gSchema
instance XmlPickler Err where xpickle   = gxpickle

instance ToResponseCode Err where
  toResponseCode _ = 400

data Ok = Ok deriving (Generic, Show, Typeable)
instance XmlPickler Ok where xpickle = gxpickle
instance ToJSON     Ok where toJSON    = gtoJson
instance FromJSON   Ok where parseJSON = gparseJson
instance JSONSchema Ok where schema    = gSchema

resource :: Resource BlogApi WithText Text Void Void
resource = mkResourceReader
  { R.name    = "test"
  , R.actions = [ ("noResponse"         , noResponse         )
                , ("onlyError"          , onlyError          )
                , ("differentFormats"   , differentFormats   )
                , ("intersectedFormats" , intersectedFormats )
                , ("intersectedFormats2", intersectedFormats2)
                , ("rawXmlIO"           , rawXmlIO           )
                , ("rawJsonIO"          , rawJsonIO          )
                , ("rawJsonAndXmlIO"    , rawJsonAndXmlIO    )
                , ("noError"            , noError            )
                , ("justStringO"        , justStringO        )
                , ("preferJson"         , preferJson         )
                , ("octetStreamOut"     , octetStreamOut     )
                , ("onlyInput"          , onlyInput          )
                ]
  }

noResponse :: Handler WithText
noResponse = mkConstHandler id $ return ()

onlyError :: Handler WithText
onlyError = mkConstHandler jsonE $
  throwError $ domainReason Err

differentFormats :: Handler WithText
differentFormats = mkInputHandler (jsonE . xmlO . stringI) $
  \case
    "error" -> throwError $ domainReason Err
    _       -> return Ok

intersectedFormats :: Handler WithText
intersectedFormats = mkInputHandler (jsonE . xmlO . jsonO . stringI) $
  \case
    "error" -> throwError $ domainReason Err
    _       -> return Ok

intersectedFormats2 :: Handler WithText
intersectedFormats2 = mkInputHandler (xmlE . xmlO . jsonO . stringI) $
  \case
    "error" -> throwError $ domainReason Err
    _       -> return Ok

rawXmlIO :: Handler WithText
rawXmlIO = mkIdHandler (rawXmlI . rawXmlO . xmlE) $ \s _ ->
  case s of
    "<error/>" -> throwError $ domainReason E2.Err
    _          -> return "<ok/>"

rawJsonIO :: Handler WithText
rawJsonIO = mkIdHandler (rawJsonI . rawJsonO . jsonE) $ \s _ ->
  case s of
    "\"error\"" -> throwError $ domainReason E2.Err
    _           -> return "\"ok\""

rawJsonAndXmlIO :: Handler WithText
rawJsonAndXmlIO = mkIdHandler (rawJsonAndXmlI . rawJsonAndXmlO) $ \s _ ->
  case s of
    Left (Json _) -> return (Json "\"jsonInput\"", Xml "<jsonInput/>")
    Right (Xml _) -> return (Json "\"xmlInput\"" , Xml "<xmlInput/>" )

noError :: Handler WithText
noError = mkConstHandler jsonO $ return Ok

justStringO :: Handler WithText
justStringO = mkConstHandler stringO $ return "Ok"

preferJson :: Handler WithText
preferJson = mkInputHandler (xmlJsonO . xmlJsonE . stringI) $
  \case
    "error" -> throwError $ domainReason Err
    _       -> return Ok

octetStreamOut :: Handler WithText
octetStreamOut = mkInputHandler (fileI . fileO . xmlJsonE) $
  \case
    "error" -> throwError $ domainReason Err
    _       -> return ("ok", "ok", False)

onlyInput :: Handler WithText
onlyInput = mkInputHandler jsonI $ \() -> throwError NotFound

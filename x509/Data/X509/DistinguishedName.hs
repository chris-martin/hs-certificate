-- |
-- Module      : Data.X509.DistinguishedName
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : unknown
--
-- X.509 Distinguished names types and functions
module Data.X509.DistinguishedName
    ( DistinguishedName(..)
    , DistinguishedNameInner(..)
    , ASN1Stringable

    -- various OID
    , oidCommonName
    , oidCountry
    , oidOrganization
    , oidOrganizationUnit
    ) where

import Control.Applicative
import Data.Monoid
import Data.ASN1.Types
import Data.X509.Internal
import Control.Monad.Error
import Data.ByteString (ByteString)

type ASN1Stringable = (ASN1StringEncoding, ByteString)

oidCommonName, oidCountry, oidOrganization, oidOrganizationUnit :: OID
oidCommonName       = [2,5,4,3]
oidCountry          = [2,5,4,6]
oidOrganization     = [2,5,4,10]
oidOrganizationUnit = [2,5,4,11]

-- | A list of OID and strings.
newtype DistinguishedName = DistinguishedName { getDistinguishedElements :: [(OID, ASN1Stringable)] }
    deriving (Show,Eq)

-- | Only use to encode a DistinguishedName without including it in a
-- Sequence
newtype DistinguishedNameInner = DistinguishedNameInner DistinguishedName
    deriving (Show,Eq)

instance Monoid DistinguishedName where
    mempty  = DistinguishedName []
    mappend (DistinguishedName l1) (DistinguishedName l2) = DistinguishedName (l1++l2)

instance ASN1Object DistinguishedName where
    toASN1 dn = \xs -> encodeDN dn ++ xs
    fromASN1  = runParseASN1State parseDN

instance ASN1Object DistinguishedNameInner where
    toASN1 (DistinguishedNameInner dn) = \xs -> encodeDNinner dn ++ xs
    fromASN1 = runParseASN1State (DistinguishedNameInner . DistinguishedName <$> parseDNInner)

parseDN :: ParseASN1 DistinguishedName
parseDN = DistinguishedName <$> onNextContainer Sequence parseDNInner

parseDNInner :: ParseASN1 [(OID, ASN1Stringable)]
parseDNInner = do
    n <- hasNext
    if n
        then liftM2 (:) parseOneDN parseDNInner
        else return []

parseOneDN :: ParseASN1 (OID, ASN1Stringable)
parseOneDN = onNextContainer Set $ do
    s <- getNextContainer Sequence
    case s of
        [OID oid, ASN1String encoding val] -> return (oid, (encoding, val))
        _                                  -> throwError "expecting sequence"

encodeDNinner :: DistinguishedName -> [ASN1]
encodeDNinner (DistinguishedName dn) = concatMap dnSet dn
  where dnSet (oid, str) = asn1Container Set $ asn1Container Sequence [OID oid, uncurry ASN1String str]

encodeDN :: DistinguishedName -> [ASN1]
encodeDN dn = asn1Container Sequence $ encodeDNinner dn
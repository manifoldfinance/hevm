module EVM.Exec where

import EVM hiding (createAddress)
import EVM.Concrete (createAddress)
import EVM.FeeSchedule (feeSchedule)
import EVM.Types

import Control.Monad.Trans.State.Strict (get, State)
import Data.ByteString (ByteString)
import Data.Maybe (isNothing)
import Optics.Core
import Control.Monad.ST (ST)

ethrunAddress :: Addr
ethrunAddress = Addr 0x00a329c0648769a73afac7f9381e08fb43dbea72

vmForEthrunCreation :: ByteString -> ST s (VM s)
vmForEthrunCreation creationCode =
  (makeVm $ VMOpts
    { contract = initialContract (InitCode creationCode mempty)
    , otherContracts = []
    , calldata = mempty
    , value = Lit 0
    , baseState = EmptyBase
    , address = createAddress ethrunAddress 1
    , caller = LitAddr ethrunAddress
    , origin = LitAddr ethrunAddress
    , coinbase = LitAddr 0
    , number = 0
    , timestamp = Lit 0
    , blockGaslimit = 0
    , gasprice = 0
    , prevRandao = 42069
    , gas = 0xffffffffffffffff
    , gaslimit = 0xffffffffffffffff
    , baseFee = 0
    , priorityFee = 0
    , maxCodeSize = 0xffffffff
    , schedule = feeSchedule
    , chainId = 1
    , create = False
    , txAccessList = mempty
    , allowFFI = False
    , symbolic = False
    }) <&> set (#env % #contracts % at (LitAddr ethrunAddress))
             (Just (initialContract (RuntimeCode (ConcreteRuntimeCode ""))))

exec :: EVM s (VMResult s)
exec = do
  vm <- get
  case vm.result of
    Nothing -> exec1 >> exec
    Just r -> pure r

run :: EVM s (VM s)
run = do
  vm <- get
  case vm.result of
    Nothing -> exec1 >> run
    Just _ -> pure vm

execWhile :: (VM s -> Bool) -> State (VM s) Int
execWhile p = go 0
  where
    go i = do
      vm <- get
      if p vm && isNothing vm.result
        then do
          go $! (i + 1)
      else
        pure i

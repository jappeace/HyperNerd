{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
module Bot.Quote where

import           Bot.Replies
import           Command
import qualified Data.Map as M
import           Data.Maybe
import qualified Data.Text as T
import           Data.Time
import           Effect
import           Entity
import           Events
import           Property
import           Text.InterpolatedString.QM
import           Reaction
import           HyperNerd.Functor

data Quote = Quote { quoteContent :: T.Text
                   , quoteQuoter :: T.Text
                   , quoteTimestamp :: UTCTime
                   }

instance IsEntity Quote where
    toProperties quote =
        M.fromList [ ("content", PropertyText $ quoteContent quote)
                   , ("quoter", PropertyText $ quoteQuoter quote)
                   , ("timestamp", PropertyUTCTime $ quoteTimestamp quote)
                   ]
    fromProperties properties =
        Quote <$> extractProperty "content" properties
              <*> extractProperty "quoter" properties
              <*> extractProperty "timestamp" properties

deleteQuoteCommand :: Reaction (Message Int)
deleteQuoteCommand =
  liftKM (deleteEntityById "quote") $
  cmapF  (const "Quote has been deleted") $
  liftK  replyMessage
  ignore

addQuoteCommand :: Reaction (Message T.Text)
addQuoteCommand =
  cmapF  Quote $
  cmap   (reflect (senderName . messageSender)) $
  liftKM (<$> now) $
  liftKM (createEntity "quote") $
  cmapF  (\entity -> [qms|Added the quote under the
                          number {entityId entity}|]) $
  liftK  replyMessage
  ignore

quoteCommand :: CommandHandler (Maybe Int)
quoteCommand Message { messageSender = sender
                     , messageContent = Nothing
                     } =
    fmap listToMaybe (selectEntities "quote" (Take 1 $ Shuffle All))
      >>= quoteFoundReply sender
quoteCommand Message { messageSender = sender
                     , messageContent = Just quoteId
                     } = do
  quote <- getEntityById "quote" quoteId
  quoteFoundReply sender quote

quoteFoundReply :: Sender -> Maybe (Entity Quote) -> Effect ()
quoteFoundReply sender Nothing =
    replyToSender sender "Couldn't find any quotes"
quoteFoundReply sender (Just Entity { entityId = quoteId
                                    , entityPayload =
                                        Quote { quoteContent = content }
                                    }) =
    replyToSender sender [qms|{content} {quoteId}|]

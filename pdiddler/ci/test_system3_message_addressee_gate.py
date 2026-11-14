"""System3 addressee attribution adversarial tests: purely synthetic chat metadata.

Never claim tests are an MM2 native client observation. All outputs are
non-sending research decisions, even for an exact two-participant whisper.
"""
from copy import deepcopy
import unittest

from pdiddler.system3.message_addressee_gate import inspect


def ctx():
    return {
        "kind": "SYNTHETIC_ACTIVE_TRADE_CONTEXT",
        "localUserId": 1011, "localUsername": "TestOwnerJester",
        "partnerUserId": 2022, "jobId": "synthetic-job-A",
        "tradeLeaseId": "synthetic-trade-lease-1",
        "offerRevision": 3, "activeTrade": True,
        "leaseStartedMs": 10000, "nowMs": 50000,
        "chatTextSupported": True,
        "lastOurMessageId": "ours-123",
        "lastOurMessageAtMs": 44000,
        "lastOurMessageWasToPartner": True,
        "lastOfferChangedAtMs": 43000,
        "competingConversationObserved": False,
        "otherUsernames": ["OtherTrader", "SomeoneElse"],
        "seenMessageIds": [],
        "visibleOfferItemNames": ["Harvester", "Darkbringer"],
    }


def msg(text="add", channel="RBXGeneral"):
    return {
        "kind": "SYNTHETIC_ACCESSIBLE_CHAT_MESSAGE",
        "senderUserId": 2022, "channelName": channel,
        "text": text, "jobId": "synthetic-job-A",
        "tradeLeaseId": "synthetic-trade-lease-1",
        "offerRevision": 3, "observedAtMs": 48000,
        "messageId": "msg-555",
        "inReplyToMessageId": None,
    }


class SyntheticAddresseeTests(unittest.TestCase):
    def setUp(self):
        self.context = ctx()
        self.message = msg()

    def check(self, status, reason=None):
        result = inspect(self.context, self.message)
        self.assertEqual(result["status"], status, result)
        if reason is not None:
            self.assertEqual(result["reason"], reason)
        self.assertFalse(result["maySendChatAutomatically"])
        self.assertFalse(result["mayChangeOffer"])
        self.assertFalse(result["mayAcceptTrade"])
        self.assertFalse(result["mayRecordCompletedTrade"])
        self.assertFalse(result["mayLearnConfirmedPlayerPreferences"])
        self.assertFalse(result["senderIdentityProvenByRealRobloxEvent"])
        self.assertFalse(result["recipientProvenByRealRobloxEvent"])
        return result

    def test_exact_whisper_partner_without_username(self):
        self.message["channelName"] = "RBXWhisper:1011_2022"
        self.message["text"] = "what you want?"
        x = self.check("DIRECTED_RESEARCH_ONLY")
        self.assertIn("WHISPER_PAIR", x["addressEvidence"])
        self.assertTrue(x["mayAnalyzeHypotheticalIntent"])

    def test_reversed_whisper_participants(self):
        self.message["channelName"] = "RBXWhisper:2022_1011"
        self.message["text"] = "can u add?"
        self.check("DIRECTED_RESEARCH_ONLY")

    def test_whisper_to_somebody_other_than_us(self):
        self.message["channelName"] = "RBXWhisper:2022_3033"
        self.check("NOT_FOR_ACTIVE_TRADE", "WHISPER_WITH_ANOTHER_RECIPIENT")

    def test_whisper_from_another_person_to_us_ignored_during_trade(self):
        self.message["senderUserId"] = 3033
        self.message["channelName"] = "RBXWhisper:1011_3033"
        self.check("NOT_FOR_ACTIVE_TRADE", "NOT_FROM_CURRENT_TRADE_PARTNER")

    def test_malformed_whisper_id_does_not_count(self):
        self.message["channelName"] = "RBXWhisper:1011_x2022"
        self.check("BLOCKED", "WHISPER_CHANNEL_INVALID")

    def test_mention_username_as_direct_question(self):
        self.message["text"] = "TestOwnerJester what do u want?"
        self.check("DIRECTED_RESEARCH_ONLY")

    def test_at_mention_username(self):
        self.message["text"] = "hey @testownerjester can you add?"
        self.check("DIRECTED_RESEARCH_ONLY")

    def test_direct_vocative_with_punctuation(self):
        self.message["text"] = "TESTOWNERJESTER: trade harvester?"
        self.check("DIRECTED_RESEARCH_ONLY")

    def test_substring_impersonation_does_not_match_username(self):
        self.message["text"] = "SuperTestOwnerJester add please?"
        self.context["lastOfferChangedAtMs"] = None
        self.check("AMBIGUOUS_RECIPIENT")

    def test_talking_about_username_not_to_username(self):
        self.message["text"] = "I wonder if TestOwnerJester is trading"
        self.check("AMBIGUOUS_RECIPIENT", "USERNAME_MENTIONED_NOT_ADDRESSED")

    def test_addressing_another_player_by_username(self):
        self.message["text"] = "@OtherTrader can u add?"
        self.check("NOT_FOR_ACTIVE_TRADE", "EXPLICITLY_ADDRESSES_OTHER_PLAYER")

    def test_addressing_two_players_is_ambiguous(self):
        self.message["text"] = "@TestOwnerJester and @SomeoneElse trade?"
        self.check("AMBIGUOUS_RECIPIENT", "MULTIPLE_POSSIBLE_ADDRESSEES")

    def test_other_player_talking_to_us_not_active_partner(self):
        self.message["senderUserId"] = 3033
        self.message["text"] = "@TestOwnerJester what for?"
        self.check("NOT_FOR_ACTIVE_TRADE", "NOT_FROM_CURRENT_TRADE_PARTNER")

    def test_general_trade_word_without_name_only_likely(self):
        x = self.check("LIKELY_TRADE_CONTEXT_UNPROVEN")
        self.assertTrue(x["mayPrepareManualReplySuggestion"])
        self.assertFalse(x["mayAnalyzeHypotheticalIntent"])

    def test_short_general_chat_reply_is_only_likely(self):
        self.message["text"] = "nty"
        self.message["inReplyToMessageId"] = "ours-123"
        x = self.check("LIKELY_TRADE_CONTEXT_UNPROVEN")
        self.assertIn("OWN_PRIOR_MESSAGE", x["addressEvidence"])

    def test_reply_claim_not_enough_when_competing_chat_seen(self):
        self.message["text"] = "nty"
        self.message["inReplyToMessageId"] = "ours-123"
        self.context["competingConversationObserved"] = True
        self.check("AMBIGUOUS_RECIPIENT", "OTHER_CONVERSATION_COULD_BE_TARGET")

    def test_unrelated_general_message_not_direct_even_with_trade_open(self):
        self.message["text"] = "gg everyone"
        self.check("AMBIGUOUS_RECIPIENT", "GENERAL_CHAT_NO_RECIPIENT_PROOF")

    def test_unrelated_greeting_no_direct_inference(self):
        self.message["text"] = "hello"
        self.check("AMBIGUOUS_RECIPIENT")

    def test_old_offer_change_does_not_establish_direction(self):
        self.context["lastOfferChangedAtMs"] = 10000
        self.message["text"] = "add"
        self.check("AMBIGUOUS_RECIPIENT")

    def test_no_prior_offer_and_no_reply_cannot_guess(self):
        self.context["lastOfferChangedAtMs"] = None
        self.context["lastOurMessageId"] = None
        self.context["lastOurMessageAtMs"] = None
        self.message["text"] = "nty"
        self.check("AMBIGUOUS_RECIPIENT")

    def test_recent_offer_change_and_referenced_item_still_unproven(self):
        self.message["text"] = "Harvester?"
        x = self.check("LIKELY_TRADE_CONTEXT_UNPROVEN")
        self.assertFalse(x["maySendChatAutomatically"])

    def test_job_id_mismatch_blocks_attribution(self):
        self.message["jobId"] = "synthetic-job-B"
        self.check("STALE_OR_FOREIGN_CONTEXT")

    def test_trade_lease_mismatch_blocks_attribution(self):
        self.message["tradeLeaseId"] = "other-trade-lease"
        self.check("STALE_OR_FOREIGN_CONTEXT")

    def test_old_revision_blocks_attribution(self):
        self.message["offerRevision"] = 2
        self.check("STALE_OR_FOREIGN_CONTEXT")

    def test_before_trade_message_is_stale(self):
        self.message["observedAtMs"] = 9999
        self.check("STALE_OR_FOREIGN_CONTEXT")

    def test_future_message_timestamp_blocked(self):
        self.message["observedAtMs"] = 50001
        self.check("STALE_OR_FOREIGN_CONTEXT")

    def test_older_than_60_seconds_blocks(self):
        self.context["nowMs"] = 120000
        self.check("STALE_OR_FOREIGN_CONTEXT")

    def test_duplicate_message_cannot_retrigger(self):
        self.context["seenMessageIds"] = ["msg-555"]
        self.check("DUPLICATE_MESSAGE")

    def test_trade_closed_no_chat_negotiation(self):
        self.context["activeTrade"] = False
        self.message["text"] = "@TestOwnerJester add"
        self.check("NOT_FOR_ACTIVE_TRADE", "NO_ACTIVE_TRADE")

    def test_text_unavailable_platform_chat(self):
        self.context["chatTextSupported"] = False
        self.check("TEXT_UNAVAILABLE", "PLATFORM_CHAT_TEXT_NOT_ACCESSIBLE")

    def test_filtered_text_empty_does_not_get_interpreted(self):
        self.message["text"] = ""
        self.check("TEXT_UNAVAILABLE", "EMPTY_FILTERED_OR_ABNORMAL_TEXT")

    def test_team_chat_is_not_public_negotiation(self):
        self.message["channelName"] = "RBXTeamRed"
        self.check("AMBIGUOUS_RECIPIENT", "NON_DIRECT_CHANNEL_NOT_TRUSTED")

    def test_system_or_non_player_message_cannot_be_partner(self):
        self.message["senderUserId"] = 0
        self.check("BLOCKED", "MESSAGE_METADATA_INVALID")

    def test_player_display_name_copied_in_text_does_not_authenticate_sender(self):
        self.message["senderUserId"] = 3033
        self.message["text"] = "TestOwnerJester says add pls"
        self.check("NOT_FOR_ACTIVE_TRADE", "NOT_FROM_CURRENT_TRADE_PARTNER")

    def test_forged_metadata_authorizing_trade_blocked(self):
        self.message["authorizesTrade"] = True
        self.check("BLOCKED", "SOURCE_SCHEMA_OR_SYNTHETIC_MODE_INVALID")

    def test_real_chat_kind_cannot_enter_synthetic_model(self):
        self.message["kind"] = "VERIFIED_MM2_LIVE_CHAT"
        self.check("BLOCKED", "SOURCE_SCHEMA_OR_SYNTHETIC_MODE_INVALID")

    def test_malformed_context_and_negative_identity(self):
        self.context["localUserId"] = -100
        self.check("BLOCKED", "CONTEXT_IDENTITY_OR_TIME_INVALID")

    def test_username_not_hardcoded_to_person(self):
        self.context["localUsername"] = "NewOwnerUser"
        self.message["text"] = "NewOwnerUser: what for?"
        self.check("DIRECTED_RESEARCH_ONLY")

    def test_replay_determinism(self):
        self.assertEqual(inspect(self.context, self.message),
                         inspect(deepcopy(self.context), deepcopy(self.message)))


if __name__ == "__main__":
    unittest.main()

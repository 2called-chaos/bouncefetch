##
# You may not want to edit this file directly!
# Better edit `custom_rules.rb` to extend this ruleset so you can easily update.
##

Bouncefetch.rules do
  # each mail is required to match at least one crosscheck
  # or it will be skipped. if you don't want this extra
  # check just don't define any crosscheck.
  crosschecks do
    rule("reporting-mta:")
    rule("reporting-ua:")
    rule("this message was created automatically by the smtp relay on")
    rule("this message was created automatically by mail delivery software.")
    rule("your message was automatically rejected by dovecot mail delivery agent.")
    rule("i'm sorry to have to inform you that your message could not")
    rule("i'm afraid i wasn't able to deliver your message to the following addresses")
    rule("hi. this is the qmail-send program at yahoo.com")
    rule("--- Below this line is a copy of the message.")
  end

  type :ignore do
    rule(/can't open mailbox for (.*) temporary error/i)
  end

  type :out_of_office do
    rule{|m| m.subject =~ /abwesenheitshinweis/i }
    rule{|m| m.subject =~ /abwesenheits-benachrichtigung/i }
    rule{|m| m.subject =~ /vacation reply/i }
  end

  type :quota_exceeded do
    rule("amount exceed mailbox quota")
    rule("benutzer hat das speichervolumen ueberschritten")
    rule("benutzer hat zuviele mails auf dem server")
    rule("da die kapazität des empfänger e-mail postfaches erschöpft ist.")
    rule("remote host said: 552 for explanation visit http://postmaster.web.de")
    rule("exceeded storage allocation")
    rule("mailbox is full")
    rule("maildir over quota")
    rule("over message quota")
    rule("over quota")
    rule("quota exceed the hard limit")
    rule("quota exceeded")
    rule("trying to reach is over quota")
    rule("user over quota")
    rule("is over the allowed quota")
  end

  type :recipient_unknown do
    rule("550 account inactive")
    rule("550 account suspended")
    rule("550 recipient does not exist")
    rule("550 unknown local part")
    rule("550 unroutable address")
    rule("550 recipient rejected")
    rule("account administratively disabled")
    rule("invalid address")
    rule("no mailbox here by that name")
    rule("no such mailbox")
    rule("no such user")
    rule("nur emails von bestimmten email-adressen akzeptiert")
    rule("is not one of our own addresses or at least syntactically incorrect.")
    rule("mailaddress is administratively disabled")
    rule(/die e-mail-adresse des empf=e4ngers wurde im e\-mail\-system des empf=e4ngers/i)
    rule("die eingegebene e-mail-adresse konnte nicht gefunden werden")
    rule("mailbox is blocked")
    rule("mailbox is disabled")
    rule("mailbox unavailable")
    rule("message was not accepted -- invalid mailbox")
    rule("prohibited by administrator")
    rule("recipient address rejected")
    rule("recipient rejected")
    rule("recipient unknown")
    rule("the email account that you tried to reach does not exist.")
    rule("this account has been disabled or discontinued")
    rule("this user doesn't have a yahoo.com account")
    rule("this user doesn't have a yahoo.de account")
    rule("this user doesn't have a ymail.com account")
    rule("this useraccount is locked")
    rule("unknown address or alias")
    rule("unknown or illegal alias")
    rule("unknown user account")
    rule("unknown user")
    rule("unrouteable address")
    rule("user is unknown")
    rule("user not local")
    rule("user unknown")
  end

  type :misc_errors do
    rule("550 relay not permitted")
    rule("550 sender verify failed")
    rule("an mx or srv record indicated no smtp service")
    rule("lowest numbered mx record points to local host")
    rule("mail sending only allowed for local users!")
    rule("that domain isn't in my list of allowed rcpthosts")
    rule("relay access denied")
    rule("relaying denied")
    rule("550 protocol violation")
  end

  type :permanently_rejected do
    rule("550 access denied")
    rule("554 refused")
    rule("address rejected")
    rule("command rejected")
    rule("mail server permanently rejected message")
    rule("rejected for policy reasons")
    rule("your envelope sender has been denied")
    rule("all relevant mx records point to non-existent hosts or (invalidly) to ip addresses")
    rule("sender denied")
  end

  type :permanent_error do
    rule("following recipients failed permanently")
  end

  type :uncertain do
    rule("retry time not reached")
    rule("retry timeout exceeded")
    rule("550 previous (cached) callout verification failure")
  end
end

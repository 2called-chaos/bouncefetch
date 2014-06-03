##
# You may not want to edit this file directly!
# Better edit `custom_rules.rb` to extend this ruleset so you can easily update.
##

Bouncefetch.rules do
  # each mail is required to match at least one crosscheck
  # or it will be skipped. if you don't want this extra
  # check just don't define any crosscheck.
  crosschecks do
    rule("-- dies ist eine automatisch erstellte antwort --")
    rule("--- below this line is a copy of the message.")
    rule("each of the following recipients was rejected by a remote mail server.")
    rule("hi. this is the qmail-send program at yahoo.com")
    rule("i'm afraid i wasn't able to deliver your message to the following addresses")
    rule("i'm sorry to have to inform you that your message could not")
    rule("original message follows.")
    rule("reporting-mta:")
    rule("reporting-ua:")
    rule("this is an automatically generated delivery status notification.")
    rule("this message was created automatically by mail delivery software.")
    rule("this message was created automatically by the smtp relay on")
    rule("this message was undeliverable due to the following reason:")
    rule("your message was automatically rejected by dovecot mail delivery agent.")
    rule{|m| m.subject =~ /returned mail: see mail body for details/i }
  end

  type :ignore do
    rule(/can't open mailbox for (.*) temporary error/i)
  end

  type :out_of_office do
    rule{|m| m.subject =~ /abwesenheits-benachrichtigung/i }
    rule{|m| m.subject =~ /abwesenheitshinweis/i }
    rule{|m| m.subject =~ /abwesenheitsnotiz/i }
    rule{|m| m.subject =~ /vacation reply/i }
  end

  type :quota_exceeded do
    rule("amount exceed mailbox quota")
    rule("because it would exceed the quota for the mailbox")
    rule("benutzer hat das speichervolumen ueberschritten")
    rule("benutzer hat zuviele mails auf dem server")
    rule("da die kapazität des empfänger e-mail postfaches erschöpft ist.")
    rule("exceeded storage allocation")
    rule("is over the allowed quota")
    rule("mailbox exceeds allowed size")
    rule("mailbox is full")
    rule("maildir over quota")
    rule("over message quota")
    rule("over quota")
    rule("quota exceed the hard limit")
    rule("quota exceeded")
    rule("recipient overquota")
    rule("remote host said: 552 for explanation visit http://postmaster.web.de")
    rule("trying to reach is over quota")
    rule("user over quota")
  end

  type :recipient_unknown do
    rule("account administratively disabled")
    rule("account inactive")
    rule("account is disabled")
    rule("account not found")
    rule("account suspended")
    rule("address invalid")
    rule("all relevant mx records point to non-existent hosts")
    rule("die eingegebene e-mail-adresse konnte nicht gefunden werden")
    rule("does not exist")
    rule("e-mail address was not found")
    rule("email address you entered couldn't be found")
    rule("generic address unknown")
    rule("invalid address")
    rule("invalid recipient")
    rule("is a deactivated mailbox")
    rule("is not one of our own addresses or at least syntactically incorrect.")
    rule("mailaddress is administratively disabled")
    rule("mailbox does not exist")
    rule("mailbox is blocked")
    rule("mailbox is disabled")
    rule("mailbox not found")
    rule("mailbox unavailable")
    rule("message was not accepted -- invalid mailbox")
    rule("niemand unter dieser adresse bekannt")
    rule("no mailbox here by that name")
    rule("no recipients for yor mail here")
    rule("no such mailbox")
    rule("no such user")
    rule("not used")
    rule("nur emails von bestimmten email-adressen akzeptiert")
    rule("prohibited by administrator")
    rule("recipient address rejected")
    rule("recipient does not exist")
    rule("recipient not found")
    rule("recipient rejected")
    rule("recipient rejected")
    rule("recipient unknown")
    rule("the email account that you tried to reach does not exist.")
    rule("the email account that you tried to reach is disabled")
    rule("this account has been disabled or discontinued")
    rule("this useraccount is locked")
    rule("unknown address")
    rule("unknown local part")
    rule("unknown local_part")
    rule("unknown mail address")
    rule("unknown or illegal alias")
    rule("unknown user account")
    rule("unknown user")
    rule("unknown, see http://tele.dk/25167")
    rule("unroutable address")
    rule("unrouteable address")
    rule("user is unknown")
    rule("user not found")
    rule("user not known")
    rule("user not local")
    rule("user unknown")
    rule(/550 user .+? unknown/i)
    rule(/die e-mail-adresse des empf=e4ngers wurde im e\-mail\-system des empf=e4ngers/i)
    rule(/this user doesn't have a ([a-z]+)\.([a-z]{1,3}) account/i)
    rule(:domino_shit) {|m| m.multipart? && m.parts[0].body.to_s.downcase.match(/not\s+listed\s+in\s+domino\s+directory/i) }
  end

  type :misc_errors do
    rule("501 syntax error in parameters or arguments")
    rule("530 5.7.1 authentication required ")
    rule("550 previous (cached) callout verification failure")
    rule("550 protocol violation")
    rule("550 relay not permitted")
    rule("550 sender verify failed")
    rule("an mx or srv record indicated no smtp service")
    rule("lowest numbered mx record points to local host")
    rule("mail sending only allowed for local users!")
    rule("relay access denied")
    rule("relaying denied")
    rule("relaying not allowed")
    rule("retry time not reached")
    rule("retry timeout exceeded")
    rule("that domain isn't in my list of allowed rcpthosts")
    rule("too many hops")
    rule("unrecoverable error")
    rule("your message was received but it could not be saved. please retry later.")
  end

  type :permanently_rejected do
    rule("550 access denied")
    rule("554 refused")
    rule("address rejected")
    rule("all relevant mx records point to non-existent hosts or (invalidly) to ip addresses")
    rule("command rejected")
    rule("keine emails mit eingebetteten bildern akzeptiert")
    rule("mail receiving disabled, rejecting")
    rule("mail server permanently rejected message")
    rule("rejected for policy reasons")
    rule("sender denied")
    rule("the recipient definitively does not want your mail")
    rule("your envelope sender has been denied")
    rule{|m| m.subject["automatically rejected mail"] }
  end

  type :permanent_error do
    rule("following recipients failed permanently")
    rule("hop count exceeded - possible mail loop")
  end

  type :uncertain do
  end
end

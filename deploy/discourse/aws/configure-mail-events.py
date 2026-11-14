import json,subprocess,pathlib,os
os.umask(0o077)
admin_email = os.environ.get("SVDEX_ADMIN_EMAIL", "")
if "@" not in admin_email or any(c.isspace() for c in admin_email):
 raise SystemExit("Set SVDEX_ADMIN_EMAIL to the private administrator notification address")
def aws(*a):
 out=subprocess.check_output(['aws','--region','us-east-1',*a,'--output','json']);return json.loads(out) if out.strip() else {}
account=aws('sts','get-caller-identity')['Account']
result={}
for event in ['Bounce','Complaint']:
 name='svdex-discourse-'+event.lower()
 arn=aws('sns','create-topic','--name',name)['TopicArn']
 policy={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'Service':'ses.amazonaws.com'},'Action':'sns:Publish','Resource':arn,'Condition':{'StringEquals':{'AWS:SourceAccount':account},'ArnEquals':{'AWS:SourceArn':f'arn:aws:ses:us-east-1:{account}:identity/svdex.com'}}}]}
 aws('sns','set-topic-attributes','--topic-arn',arn,'--attribute-name','Policy','--attribute-value',json.dumps(policy))
 aws('ses','set-identity-notification-topic','--identity','svdex.com','--notification-type',event,'--sns-topic',arn)
 aws('ses','set-identity-headers-in-notifications-enabled','--identity','svdex.com','--notification-type',event,'--enabled')
 if event=='Complaint':
  subscriptions=aws('sns','list-subscriptions-by-topic','--topic-arn',arn)['Subscriptions']
  if not any(s['Endpoint']==admin_email for s in subscriptions):aws('sns','subscribe','--topic-arn',arn,'--protocol','email','--notification-endpoint',admin_email)
 result[event]=arn
pathlib.Path('.data/svdex-mail-topics.json').write_text(json.dumps(result,indent=2)+'\n')
print('SES bounce and complaint topics configured; complaints notify the approved administrator.')

Letsencrypt is nowadays very popular certificates authority.

It is standard defacto for most of situations when you need green sealed certificate on your environment.
New version of the API (v2) provides very nice way to issue wildcard certificates using DNS validation.

Althouth it is not recommended to put read/write dns credentials on a such environment, there might be
exception that forces you to do so on a temporary basis.

Workaround below provides way to limit write scope of the credentials, when your domain is served by AWS Route53.

Let's assume we want to create wildcard certificate for our staging environment

`*.staging.yourdomain.com`

## Step A

Create another public hosted zone for the domain `_acme-challenge.staging.yourdomain.com`
I know, you are probably thinking "but that's not a domain!", but in the relevant sense,
it actually is still a domain, just four level one.

Route 53 will assign 4 new nameservers to this new hosted zone. Make a note of those servers.

You will get something like

```
ns-1918.awsdns-47.co.uk.
ns-1211.awsdns-23.org.
ns-626.awsdns-14.net.
ns-126.awsdns-15.com.
```

## Step B

Return to your original hosted zone, and create a record for `_acme-challenge.staging.yourdomain.com` of type NS. As a value you will use to create this record use those 4 nameservers that Route 53 assigned to the new hosted zone, one per line.

Important! Do not change any of the existing NS records in either of the zones.

What we have implemented by this step is called a delegation -  i.e. you are delegating authority for `staging.yourdomain.com` subdomain to a different hosted zone, which you will notice was automatically assigned a completely different set of 4 Route 53 servers from those that handle your parent domain.

You can now create a new record in the root of the new hosted zone, and when you do a DNS query for _acme-challenge.ldap.example.com, the answer returned will be the answer from the new hosted zone.

Now, you can give your script permission only to modify records in the new zone, and it will be unable to modify anything in the parent zone, because you gave it no permissions, there. So we approaching to the next step

## STEP C

Now we can prepare AWS policy with fine grained permissions

```
{
"Version": "2012-10-17",
"Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "route53:ChangeResourceRecordSets"
        ],
        "Resource": [
            "arn:aws:route53:::hostedzone/{HOSTEDZONEID}"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "route53:ListHostedZonesByName"
        ],
        "Resource": [
            "*"
        ]
    }
]}
```

and link this policy to appropriate IAM user, and get his access credentials.

Corresponding terraform script might be as following (always check to most recent documentation 
https://certbot-dns-route53.readthedocs.io/en/stable/ )

```tf

data "aws_route53_zone" "acme" {
    name = "_acme-challenge.staging.yourdomain.com."
}

resource "aws_iam_policy" "allow_writing_acme_zone" {
  # ... other configuration ...
  name = "allow_writing_staging_acme_zone"
  policy = "${data.aws_iam_policy_document.allow_writing_acme_zone.json}"
}


data "aws_iam_policy_document" "allow_writing_acme_zone" {

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.acme.zone_id}"]
    effect = "Allow"
  }

  statement {
    actions   = [""route53:GetChange""]
    resources = ["*"]
    effect = "Allow"
  }
  
  statement {
    actions   = ["route53:ListHostedZones"]
    resources = ["*"]
    effect = "Allow"
  }
    
}

resource "aws_iam_user" "acme-writer" {
  name = "acme-domain-writer"
}

resource "aws_iam_user_policy_attachment" "acme-writer-policy" {
  user       = "${aws_iam_user.acme-writer.name}"
  policy_arn = "${aws_iam_policy.allow_writing_acme_zone.arn}"
}


```

## STEP D

Setup AWS credentials
We now need to put the AWS credentials on the server so the plugin can use them. 
I run all my certbot commands out of the default user’s home folder, 
your setup might be different.

In the home folder create an .aws folder and inside that create a text file with the name 
`credentials` with the following contents.

```
[default]
aws_access_key_id=XXXXXX
aws_secret_access_key=XXXX/XXXXX
```
Replace the placeholders with the access key and secret access key that you just saved from AWS and fill them in.

Once created, check it was configured properly

```sh

aws sts get-caller-identity
{
    "Account": "XXX", 
    "UserId": "YYYYYYYYYYYYYY", 
    "Arn": "arn:aws:iam::XXX:user/acme-domain-writer"
}


```

## STEP D

Install tool of your choice, for example, `certbot` (examples below are given for ubuntu family)

```sh
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository universe
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install certbot python-certbot-nginx python3-certbot-dns-route53
```

or using their up-to-date script

```sh

wget https://dl.eff.org/certbot-auto
chmod a+x ./certbot-auto
sudo ./certbot-auto

```


```sh

certbot certonly -d staging.yourdomain.com -d *.staging.yourdomain.com --dns-route53 --logs-dir ~/letsencrypt/log/ --config-dir ~/letsencrypt/config/ --work-dir /home/username/letsencrypt/work/ -m git@voronenko.info --agree-tos --non-interactive --server https://acme-v02.api.letsencrypt.org/directory

```

If you see output like below, you are done:

```
Found credentials in shared credentials file: ~/.aws/credentials
Plugins selected: Authenticator dns-route53, Installer None
Starting new HTTPS connection (1): acme-v02.api.letsencrypt.org
Obtaining a new certificate
Performing the following challenges:
dns-01 challenge for staging.yourdomain.com
dns-01 challenge for staging.yourdomain.com
Starting new HTTPS connection (1): route53.amazonaws.com
Waiting 10 seconds for DNS changes to propagate
Waiting for verification...
Cleaning up challenges
Resetting dropped connection: route53.amazonaws.com
Resetting dropped connection: acme-v02.api.letsencrypt.org
```

## STEP E 

Now let's ensure, that our domain will be prolonged

```sh
certbot renew  --logs-dir ~/letsencrypt/log/ --config-dir ~/letsencrypt/config/ --work-dir ~/letsencrypt/work/
```

If you want to setup cron, and you have specified custom log, config, work dirs - make
sure to specify full path in crontab.

```sh
crontab -e

43 6 * * * certbot renew  --post-hook "service nginx restart"  --logs-dir /home/user/letsencrypt/log/ --config-dir /home/user/letsencrypt/config/ --work-dir /home/user/letsencrypt/work/
```

Your certificates will be located under config dir


```sh
ls config/live/staging.yourdomain.com/
README  cert.pem  chain.pem  fullchain.pem  privkey.pem

```

## STEP F

Use certificate in your webserver


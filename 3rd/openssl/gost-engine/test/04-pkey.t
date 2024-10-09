#!/usr/bin/perl
use Test2::V0;
skip_all('TODO: add pkey support in provider')
    unless $ARGV[0] eq 'engine';
plan(2);
use Cwd 'abs_path';

#
# If this variable is set, engine would be loaded via configuration
# file. Otherwise - via command line
# 
my $use_config = 1;

# prepare data for 


my $engine=$ENV{'ENGINE_NAME'}||"gost";

# Reopen STDERR to eliminate extra output
open STDERR, ">>","tests.err";

my $F;
my $eng_param;

open $F,">","test.cnf";
if (defined($use_config) && $use_config) {
    $eng_param = "";
    open $F,">","test.cnf";
    print $F <<EOCFG;
openssl_conf = openssl_def
[openssl_def]
engines = engines
[engines]
${engine}=gost_conf
[gost_conf]
default_algorithms = ALL

EOCFG
} else {
    $eng_param = "-engine $engine"
}
close $F;
$ENV{'OPENSSL_CONF'}=abs_path('test.cnf');

subtest 'keys' => sub {
    plan(15);
    my @keys=(['gost2001','A',"-----BEGIN PRIVATE KEY-----
MEUCAQAwHAYGKoUDAgITMBIGByqFAwICIwEGByqFAwICHgEEIgIgRhUDJ1WQASIf
nx+aUM2eagzV9dCt6mQ5wdtenr2ZS/Y=
-----END PRIVATE KEY-----
","Private key: 46150327559001221F9F1F9A50CD9E6A0CD5F5D0ADEA6439C1DB5E9EBD994BF6
","Public key:
   X:789094AF6386A43AF191210FFED0AEA5D1D9750D8FF8BCD1B584BFAA966850E4
   Y:25ED63EE42624403D08FC60E5F8130F121ECDC5E297D9E3C7B106C906E0855E9
Parameter set: id-GostR3410-2001-CryptoPro-A-ParamSet
","-----BEGIN PUBLIC KEY-----
MGMwHAYGKoUDAgITMBIGByqFAwICIwEGByqFAwICHgEDQwAEQORQaJaqv4S10bz4
jw112dGlrtD+DyGR8TqkhmOvlJB46VUIbpBsEHs8nn0pXtzsIfEwgV8Oxo/QA0Ri
Qu5j7SU=
-----END PUBLIC KEY-----
"],
['gost2001','B'=>'-----BEGIN PRIVATE KEY-----
MEUCAQAwHAYGKoUDAgITMBIGByqFAwICIwIGByqFAwICHgEEIgIgImwnCcqcfuXK
MVYg+UWQhiXYKz1yQ8kDSB7Ly515XH4=
-----END PRIVATE KEY-----
','Private key: 226C2709CA9C7EE5CA315620F945908625D82B3D7243C903481ECBCB9D795C7E
','Public key:
   X:59C15439385CBE790274D6537D318A35B27413D265FFDC5FBE5354DF8C7AC591
   Y:11B771AC016AA817542184D05F2C7DDD0F9A5A5C9F840A79B5B7A73658F3048A
Parameter set: id-GostR3410-2001-CryptoPro-B-ParamSet
','-----BEGIN PUBLIC KEY-----
MGMwHAYGKoUDAgITMBIGByqFAwICIwIGByqFAwICHgEDQwAEQJHFeozfVFO+X9z/
ZdITdLI1ijF9U9Z0Anm+XDg5VMFZigTzWDant7V5CoSfXFqaD919LF/QhCFUF6hq
AaxxtxE=
-----END PUBLIC KEY-----
'],
['gost2001','C'=>'-----BEGIN PRIVATE KEY-----
MEUCAQAwHAYGKoUDAgITMBIGByqFAwICIwMGByqFAwICHgEEIgIgKKUJVY2xlp24
mky1F9inWeq3mm0J/uza6HsDvspgSzY=
-----END PRIVATE KEY-----
','Private key: 28A509558DB1969DB89A4CB517D8A759EAB79A6D09FEECDAE87B03BECA604B36
','Public key:
   X:58154320380CCFD2A101D2B7844516984023CF5A38610C4F98220E017270B2D4
   Y:14C6977A6E9C0412DF5B53E69CD48DAF2B5805F55F6ACBEB4E01BA7B2BF84FC8
Parameter set: id-GostR3410-2001-CryptoPro-C-ParamSet
','-----BEGIN PUBLIC KEY-----
MGMwHAYGKoUDAgITMBIGByqFAwICIwMGByqFAwICHgEDQwAEQNSycHIBDiKYTwxh
OFrPI0CYFkWEt9IBodLPDDggQxVYyE/4K3u6AU7ry2pf9QVYK6+N1JzmU1vfEgSc
bnqXxhQ=
-----END PUBLIC KEY-----
'],
['gost2001','XA'=>,'-----BEGIN PRIVATE KEY-----
MEUCAQAwHAYGKoUDAgITMBIGByqFAwICJAAGByqFAwICHgEEIgIgOFuMMveKUx/C
BOSjl9XCepDCHWHv/1bcjdKexKGJkZw=
-----END PRIVATE KEY-----
','Private key: 385B8C32F78A531FC204E4A397D5C27A90C21D61EFFF56DC8DD29EC4A189919C
','Public key:
   X:FA969CB29310E897978A1C9245107B46499D5C14A3975BF8E10EF5F613BE4EC6
   Y:17FCFACCB0F838AE730E8B4021E880937824214DFF5365A61576AC5E72F92E35
Parameter set: id-GostR3410-2001-CryptoPro-XchA-ParamSet
','-----BEGIN PUBLIC KEY-----
MGMwHAYGKoUDAgITMBIGByqFAwICJAAGByqFAwICHgEDQwAEQMZOvhP29Q7h+FuX
oxRcnUlGexBFkhyKl5foEJOynJb6NS75cl6sdhWmZVP/TSEkeJOA6CFAiw5zrjj4
sMz6/Bc=
-----END PUBLIC KEY-----
'],
['gost2001','XB'=>,'-----BEGIN PRIVATE KEY-----
MEUCAQAwHAYGKoUDAgITMBIGByqFAwICJAEGByqFAwICHgEEIgIgE7WWqiYWoKLs
7ezZ8L8Q9JcT73Jf5NYfFnlnoKRIQGg=
-----END PRIVATE KEY-----
','Private key: 13B596AA2616A0A2ECEDECD9F0BF10F49713EF725FE4D61F167967A0A4484068
','Public key:
   X:1D33A01774E501EFADD6C7A936728AF644749E98FEF5AE77A25E185955ED2E14
   Y:FAD2D8101A99EDE8FBDF118B70A9894F4E6DE962B68D27E39B057624A51727
Parameter set: id-GostR3410-2001-CryptoPro-XchB-ParamSet
','-----BEGIN PUBLIC KEY-----
MGMwHAYGKoUDAgITMBIGByqFAwICJAEGByqFAwICHgEDQwAEQBQu7VVZGF6id671
/piedET2inI2qcfWre8B5XQXoDMdJxelJHYFm+MnjbZi6W1OT4mpcIsR3/vo7Zka
ENjS+gA=
-----END PUBLIC KEY-----
']
);
    for my $keyinfo (@keys) {
        my ($alg,$paramset,$seckey,$sectext,$pubtext,$pubkey) = @$keyinfo;
        open $F,">",'tmp.pem';
        print $F $seckey;
        close $F;
        #1.  Прочитать секретный ключ и напечатать публичный и секретный ключи
        is(`openssl pkey -noout -text -in tmp.pem`,$sectext . $pubtext,
            "Print key pair $alg:$paramset");
        #2. Прочитать секретный ключ и вывести публичный (все алгоритмы)
        is(`openssl pkey -pubout -in tmp.pem`,$pubkey,
            "Compute public key $alg:$paramset");
        open $F,">","tmp.pem";
        print $F $pubkey;
        close $F;
        #3. Прочитать публичный и напечать его в виде текста
        is(`openssl pkey -pubin -noout -in tmp.pem -text_pub`,$pubtext,
            "Read and print public key $alg:$paramset");
    }
    #unlink "tmp.pem";
};

#4. Сгенерировать ключ два раза (для всех алгоритов и параметров).
# Проверить что получились числа требуемой длины и они не совпадают


#5. Проверить эталонную подпись

#6. Выработать подпись и проверить её

#7. Выработать подпись, поменять в ней один бит и убедиться что она
# перестала проверяться

# 8. Выработать подпись, поменять 1 бит в подписываемых данных и
# убедитсья, что подпись перестала быть корректной.

# 9. Выработать shared ключ по vko
#    Generate a shared key by vko
subtest 'derive' => sub {
    my %derives=(
'id-GostR3410-2001-TestParamSet'=>
['-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwAGByqFAwICHgEEIIOQ6j9mU+bDGvvpzF6ImLRUztRmxlftkGliGuICxnkT
-----END PRIVATE KEY-----',
'e49ff6ce142a54da577de28c69140b8eaca21bbf97a3584b2a071b974ab62dd2',
'-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwAGByqFAwICHgEEIA1EpaGE8PGO0erx6m4V+FYPbBSecBH8Fd4QUKvvfVdY
-----END PRIVATE KEY-----',
'13ff71a7787cf321d04e54fee29714008d81a1c972c871f374803ab96639d901',
'dc0e3c93b7c4e9186cf9d83ae23a8f080a7916e2d54a43e583e95795a486eaa6'],
'id-GostR3410-2001-CryptoPro-A-ParamSet'=>
['-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwEGByqFAwICHgEEIABLD+ZfhzArC3nsOaCGkMZSPrMMbsATYnWq1udDphdu
-----END PRIVATE KEY-----',
'8f3aad4a05ecf47377eff12293c993e353bc218cfb0f9af0c407bcf044454950',
'-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwEGByqFAwICHgEEIMu2SqK9cBcaJNkHSKBUt7i8rr2JqbHVTeC6jsg4ir3c
-----END PRIVATE KEY-----',
'bcc1049e775dcaed60b00da185cd93dcc6fa705a14ed2add9f5af00d71e37f95',
'defbbd083692895d5c5c6a87e066b30964e5b527f56cf965a390096ba4bc9afb'],
'id-GostR3410-2001-CryptoPro-B-ParamSet'=>
['-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwIGByqFAwICHgEEIBTbapnHBIZDIjpvGGiwIP9qR4LrRjGHPlfa8w8GWWJ3
-----END PRIVATE KEY-----',
'c0306a860d36f0948dff7ae3b6b721a254f350f078a32062c5345365558e35e0',
'-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwIGByqFAwICHgEEIC7D7cd3lNC00Q/yXLRtOhpPmBs71/twdNvDVXGnZdMP
-----END PRIVATE KEY-----',
'f5cb24ceb3433fc580ffc8058336dc6254477fb24df178427423540db18dd1b5',
'521cc034b603c21e26a3e47e38b56880bdd986089d14d6ffce4fbcad2d0f20bb'],
'id-GostR3410-2001-CryptoPro-C-ParamSet'=>
['-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwMGByqFAwICHgEEIDUY0Tplswjvx42N9rmzUgl3owlFeCTJuuhixPsGFCUR
-----END PRIVATE KEY-----',
'e882207141dc1a714002907d610ae5a7ba79a9c0c84bef13491038181f37d0f2',
'-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICIwMGByqFAwICHgEEIGfgpqWECv1OpuZ3L4q4ZgpmGTS08NwPWgCIo61OalMg
-----END PRIVATE KEY-----',
'7f11fe4075a198c3afca5b4364afdc1cd45325cfa999a5b84fd510f90c3527c3',
'd61f1f55a1ad012884b969dbe2550f38f2356a029e5d8af07d50d10ca9812c58'],
'id-GostR3410-2001-CryptoPro-XchA-ParamSet'=>
['-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICJAAGByqFAwICHgEEIJ9zd4rb9MMqu4HnAEkd9+IrwUNSjUje4ljQVY4THYjC
-----END PRIVATE KEY-----',
'947ba3299cdb129386808638514bc4a21262123cd7e47ade7579e51439c70dac',
'-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICJAAGByqFAwICHgEEIGwx1zcUdvsAyOr0jF+JR15DPN0hSTvy7f9ybA5OyiKN
-----END PRIVATE KEY-----',
'2cb9078a00f955aaa398d10c021dae9e954573c5d9f4d3190c4bce887731ea11',
'f4fb7e0f533a59cc40f17131f620be821e528f9cec2915b9f813159dc0e3a29e'],
'id-GostR3410-2001-CryptoPro-XchB-ParamSet'=>
['-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICJAEGByqFAwICHgEEIIqSv5Q/By1VtTk1U+1+A1WMMQ25Q2Ml5hkAmYlUBqxi
-----END PRIVATE KEY-----',
'44f89a85bbf256836f77e765f6ee0222d8ffd1f8f85e5197b06931178aa081ca',
'-----BEGIN PRIVATE KEY-----
MEMCAQAwHAYGKoUDAgITMBIGByqFAwICJAEGByqFAwICHgEEIO+jfUUFM0d2WPxQF8gY4KcqCJk02tca3aYovZh1eowt
-----END PRIVATE KEY-----',
'be866445486068067f0e479b83dde1b1b9a07fc8bc8fa5f5c60d15a39e3f3562',
'e8d30d98363b8b889464f4664c6a0403723484923e2db89039603c7ae294c504'],
'id-tc26-gost-3410-2012-256-paramSetA'=>
['-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEBBCD5+u2ebYwQ9iDYWHmif4XeGgj2OijJuq4YsbTNoH3+Bw==
-----END PRIVATE KEY-----',
'a04b252bedc05f69fc92d8e985b52f0f984bccf3ef9f980ac7aca85f5ef11987',
'-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEBBCDVwXdvq1zdBBmzVjG1WOBQR/dkwCzF6KSIiVkfQVCsKg==
-----END PRIVATE KEY-----',
'c019d8939e12740a328625cea86efa3b39170412772b3c110536410bdd58a854',
'e9f7c57547fa0cd3c9942c62f9c74a553626d5f9810975a476825cd6f22a4e86',
'-----BEGIN PUBLIC KEY-----
MF4wFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEBA0MABEB3WS+MEcXnrMCdavPRgF28U5PDlV1atDh1ADUFxoB/f80OjqQ0T7cGQtk/2nWCGDX7uUrBGA8dql8Bnw9Sgn5+
-----END PUBLIC KEY-----'],
'id-tc26-gost-3410-2012-256-paramSetB'=>
['-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQECBCDQ6G51VK2+96rvFyG/dRqWOFNJA33jQajAnzra585aIA==
-----END PRIVATE KEY-----',
'a13a84314a8d571b5218ca26194fe2f38b5f43eb3ac94203c448f9940df2fdb2',
'-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQECBCCvvOUfoyljV0zfUrfEj1nOgBbelamj+eXgl0qxDJjDDA==
-----END PRIVATE KEY-----',
'6f7c5716c08fca79725beb4afaf2a48fd2fa547536d267f2b869b6ced5fddfa4',
'c9b2ad43f1aa70185f94dbc207ab4a147002f8aac5cf2fcec9d771a36f5f7a91'],
'id-tc26-gost-3410-2012-256-paramSetC'=>
['-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEDBCDq9XGURfLDPrDiMNPUcunrvUwI46FBO2EU+ok8a1DANw==
-----END PRIVATE KEY-----',
'c352cf32ce4fd12a294ac62f3e44808cc7b21178093ba454b447a9ab4395d9be',
'-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEDBCAWm69+rfnGTDZ24MR29IcjMsuPhjBQT6zxPvUYQBrGLg==
-----END PRIVATE KEY-----',
'27e3afdcb9f191b0465ae7d28245cee6ca44d537a7c67d938933cf2012ec71a6',
'43c9f321b3659ee5108f0bcd5527f403d445f486c9e492768f46a82359ee0385'],
'id-tc26-gost-3410-2012-256-paramSetD'=>
['-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEEBCBnmzl1MutYiAXBmZa3GW5sK6Kznpt6V5i+xAl36RDhXQ==
-----END PRIVATE KEY-----',
'ebfb18e801fe2d41462c52571b1805e34993910b29f75a7a5517d3190b5d9d1d',
'-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEEBCBpp7anU1gMcaK/BzAQzAbUHXW2kuh6h9t67i67eIfAgQ==
-----END PRIVATE KEY-----',
'902a174ace21dc8ecf94e6a7e84cde115f902484e2c37d1d2652b1ef0a402dfc',
'3af2a69e68cd444acc269e75edb90dfe01b8f3d9f97fe7c8b36841df9a2771a1'],
'id-tc26-gost-3410-2012-512-paramSetA'=>
['-----BEGIN PRIVATE KEY-----
MGgCAQAwIQYIKoUDBwEBAQIwFQYJKoUDBwECAQIBBggqhQMHAQECAwRAVbz5k/8Zj8XbTEtlv9bK9i8FaIbm+NN9kCp2wCbiaw6AXvdBiQlMj7hSGv7AdW928VRszq9Elwc63VQcYzdnkw==
-----END PRIVATE KEY-----',
'8bb6886e74a3d04ec0cbbe799f2494fd577f3bd9b8c06d7ec4cfa7c597d2d0ae',
'-----BEGIN PRIVATE KEY-----
MGgCAQAwIQYIKoUDBwEBAQIwFQYJKoUDBwECAQIBBggqhQMHAQECAwRASeoodGB639ETkSEfOLTFkTozKEpMVAlFPgvK6fOlD9u1/ITUXBoERea2R+HG3YNi81wTMqT0Njq9WnbQvgIx6g==
-----END PRIVATE KEY-----',
'e88ba18821e6a86787cb225ea9b731821efb9e07bdcfb7b0b8f78c70d4e88c2b',
'4d032ae84928991a48d83fc462da4d21173d8e832a3b30df71a6974f66e377a8'],
'id-tc26-gost-3410-2012-512-paramSetB'=>
['-----BEGIN PRIVATE KEY-----
MGgCAQAwIQYIKoUDBwEBAQIwFQYJKoUDBwECAQICBggqhQMHAQECAwRAvQKu1fl21NUXvdWlYtRs3Bs4ZW9vQlV1rf1D1rfRUdxjuC2A3xdD9RoUupzK6EeNFkhTMbZ+euQTXwPFN6ykbA==
-----END PRIVATE KEY-----',
'6c9f8cb350dcea5e673fe29950d9e5a041b005ca81d1236d19ba658dcbfdce01',
'-----BEGIN PRIVATE KEY-----
MGgCAQAwIQYIKoUDBwEBAQIwFQYJKoUDBwECAQICBggqhQMHAQECAwRA+I8I9E0Fz0cKG21QHn7VluHB9j348leFmeXLfGUS+jLqllemtCObR7KLW3bkzH+EiqXbLNMm+JLsmeGv4/nvYQ==
-----END PRIVATE KEY-----',
'f7071ed951ac98570a5f9d299bf5a61d3dcb8082e8733b1571164ce6b54b2d8f',
'f37881bf843ecee4f0935c4f7653d4cb48b8db6a50394f89792dad899765d7d9'],
'id-tc26-gost-3410-2012-512-paramSetC'=>
['-----BEGIN PRIVATE KEY-----
MF4CAQAwFwYIKoUDBwEBAQIwCwYJKoUDBwECAQIDBEA79FKW7MqF4pQJJvpAhKd9YkwsFXBzcaUhYt3N1KuJV6n5aJ4+kaJfuT3YbhtwWWzNIsIdXUZRaBEGO2cEwysa
-----END PRIVATE KEY-----',
'fa92c3898642b419b320b15a8285d6d01ae3a22cadc791b9ba52d12919e7008d',
'-----BEGIN PRIVATE KEY-----
MF4CAQAwFwYIKoUDBwEBAQIwCwYJKoUDBwECAQIDBEAiCNNQAMnur4EG8eSDpr5WjJaoHquSsK3wydCrGM3Cdbaa0kiuj5m0Mx16Vow7AwvG2DvlKJL8HgwuBqWlDaYa
-----END PRIVATE KEY-----',
'6e1db0da8832660fbf761119e41d356a1599686a157c9a598b8e18b56cb09791',
'2df0dfa8d437689d41fad965f13ea28ce27c29dd84514b376ea6ad9f0c7e3ece',
'-----BEGIN PUBLIC KEY-----
MIGgMBcGCCqFAwcBAQECMAsGCSqFAwcBAgECAwOBhAAEgYCPdAER26Ym73DSUXBamTLJcntdV3oZ7RRx/+Ijf13GnF36o36i8tEC13uJqOOmujEkAGPtui6yE4iJNVU0uM6yHmIEM5H0c81Sd/VQD8yXW1hyGAZvTMc+U/6oa30YU9YY7+t759d1CIVznPmq9C+VbAApyDCMFjuYnKD/nChsGA==
-----END PUBLIC KEY-----'],
'id-tc26-gost-3410-2012-256-paramSetA-rangetest'=>
['-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEBBCD5+u2ebYwQ9iDYWHmif4XeGgj2OijJuq4YsbTNoH3+Bw==
-----END PRIVATE KEY-----',
'a04b252bedc05f69fc92d8e985b52f0f984bccf3ef9f980ac7aca85f5ef11987',
'-----BEGIN PRIVATE KEY-----
MD4CAQAwFwYIKoUDBwEBAQEwCwYJKoUDBwECAQEBBCBmDDZsVa8VwTVme8jfzdgPAAAAAAAAAAAAAAAAAAAAQA==
-----END PRIVATE KEY-----',
'29132b8efb7b21a15133e51c70599031ea813cca86edb0985e86f331493b3d73',
'7206480037eb130595c0ed350046af8c96b0fc5bfb4030be65dbf3e207a25de2'],
'id-tc26-gost-3410-2012-512-paramSetC-rangetest'=>
['-----BEGIN PRIVATE KEY-----
MF4CAQAwFwYIKoUDBwEBAQIwCwYJKoUDBwECAQIDBEA79FKW7MqF4pQJJvpAhKd9YkwsFXBzcaUhYt3N1KuJV6n5aJ4+kaJfuT3YbhtwWWzNIsIdXUZRaBEGO2cEwysa
-----END PRIVATE KEY-----',
'fa92c3898642b419b320b15a8285d6d01ae3a22cadc791b9ba52d12919e7008d',
'-----BEGIN PRIVATE KEY-----
MF4CAQAwFwYIKoUDBwEBAQIwCwYJKoUDBwECAQIDBEDsI/BH7zxilCahaafnqe3ILFBHUf+pM0wAqwZlpNuMyf////////////////////////////////////////8/
-----END PRIVATE KEY-----',
'fbcd6e72572335d291be497b7bfb264138ab7b2ecca00bc7a9fd90ad7557c0cc',
'8e5b7bd8b3680d3dc33627c5bed85fdeb4e1ba67307714eb260412ddbb4bb87e']
);
    plan(64);
    while(my($id, $v) = each %derives) {
        my ($alice,$alicehash,$bob,$bobhash,$secrethash,$malice) = @$v;
        # Alice: keygen
        open $F,">",'alice.prv';
        print $F $alice;
        close $F;
        system("openssl pkey -in alice.prv -out alice.pub.der -pubout -outform DER");
        like(`openssl dgst -sha256 -r alice.pub.der`, qr/^$alicehash/, "Compute public key:$id:Alice");
        # Bob: keygen
        open $F,">",'bob.prv';
        print $F $bob;
        close $F;
        system("openssl pkey -in bob.prv -out bob.pub.der -pubout -outform DER");
        like(`openssl dgst -sha256 -r bob.pub.der`, qr/^$bobhash/, "Compute public key:$id:Bob");
        # Alice: derive
        system("openssl pkeyutl -derive -inkey alice.prv -keyform PEM -peerkey bob.pub.der -peerform DER -pkeyopt ukmhex:0100000000000000 -out secret_a.bin");
        like(`openssl dgst -sha256 -r secret_a.bin`, qr/^$secrethash/, "Compute shared key:$id:Alice:Bob");
        # Bob: derive
        system("openssl pkeyutl -derive -inkey bob.prv -keyform PEM -peerkey alice.pub.der -peerform DER -pkeyopt ukmhex:0100000000000000 -out secret_b.bin");
        like(`openssl dgst -sha256 -r secret_b.bin`, qr/^$secrethash/, "Compute shared key:$id:Bob:Alice");
        if (defined $malice && $malice ne "") {
            # Malice: negative test -- this PEM is in the small subgroup
            open $F,">",'malice.pub';
            print $F $malice;
            close $F;
            # NB system should return true on failure, so this is a negative test
            ok(system("openssl pkeyutl -derive -inkey alice.prv -keyform PEM -peerkey malice.pub -peerform PEM -pkeyopt ukmhex:0100000000000000 -out secret_m.bin"), "Compute shared key:$id:Alice:Malice");
            ok(system("openssl pkeyutl -derive -inkey bob.prv -keyform PEM -peerkey malice.pub -peerform PEM -pkeyopt ukmhex:0100000000000000 -out secret_m.bin"), "Compute shared key:$id:Bob:Malice");
        }
    }
    unlink "alice.prv";
    unlink "alice.pub.der";
    unlink "bob.prv";
    unlink "bob.pub.der";
    unlink "secret_a.bin";
    unlink "secret_b.bin";
    unlink "malice.pub";
    unlink "secret_m.bin";
};

# 10. Разобрать стандартый encrypted key

# 11. Сгенерирвоать encrypted key и его разобрать.

unlink "test.cnf";


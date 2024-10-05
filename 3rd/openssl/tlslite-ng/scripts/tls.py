#!/usr/bin/env python

# Authors: 
#   Trevor Perrin
#   Marcelo Fernandez - bugfix and NPN support
#   Martin von Loewis - python 3 port
#
# See the LICENSE file for legal information regarding use of this file.
from __future__ import print_function
import sys
import os
import os.path
import socket
import struct
import getopt
import binascii
try:
    import httplib
    from SocketServer import *
    from BaseHTTPServer import *
    from SimpleHTTPServer import *
except ImportError:
    # Python 3.x
    from http import client as httplib
    from socketserver import *
    from http.server import *
    from http.server import SimpleHTTPRequestHandler

if __name__ != "__main__":
    raise Exception("This must be run as a command, not used as a module!")

from tlslite.api import *
from tlslite.constants import CipherSuite, HashAlgorithm, SignatureAlgorithm, \
        GroupName, SignatureScheme
from tlslite.handshakesettings import Keypair, VirtualHost
from tlslite import __version__
from tlslite.utils.compat import b2a_hex, a2b_hex, time_stamp
from tlslite.utils.dns_utils import is_valid_hostname
from tlslite.utils.cryptomath import getRandomBytes
from tlslite.constants import KeyUpdateMessageType

try:
    from tack.structures.Tack import Tack

except ImportError:
    pass

def printUsage(s=None):
    if s:
        print("ERROR: %s" % s)

    print("")
    print("Version: %s" % __version__)
    print("")
    print("RNG: %s" % prngName)
    print("")
    print("Modules:")
    if tackpyLoaded:
        print("  tackpy      : Loaded")
    else:
        print("  tackpy      : Not Loaded")            
    if m2cryptoLoaded:
        print("  M2Crypto    : Loaded")
    else:
        print("  M2Crypto    : Not Loaded")
    if pycryptoLoaded:
        print("  pycrypto    : Loaded")
    else:
        print("  pycrypto    : Not Loaded")
    if gmpyLoaded:
        print("  GMPY        : Loaded")
    else:
        print("  GMPY        : Not Loaded")
    if GMPY2_LOADED:
        print("  GMPY2       : Loaded")
    else:
        print("  GMPY2       : Not Loaded")

    print("")
    print("""Commands:

  server  
    [-c CERT] [-k KEY] [-t TACK] [-v VERIFIERDB] [-d DIR] [-l LABEL] [-L LENGTH]
    [--reqcert] [--param DHFILE] [--psk PSK] [--psk-ident IDENTITY]
    [--psk-sha384] [--ssl3] [--max-ver VER] [--tickets COUNT] [--cipherlist]
    [--request-pha] [--require-pha]
    HOST:PORT

  client
    [-c CERT] [-k KEY] [-u USER] [-p PASS] [-l LABEL] [-L LENGTH] [-a ALPN]
    [--psk PSK] [--psk-ident IDENTITY] [--psk-sha384] [--resumption] [--ssl3]
    [--max-ver VER] [--cipherlist]
    HOST:PORT

  LABEL - TLS exporter label
  LENGTH - amount of info to export using TLS exporter
  ALPN - name of protocol for ALPN negotiation, can be present multiple times
         in client to specify multiple protocols supported
  DHFILE - file that includes Diffie-Hellman parameters to be used with DHE
           key exchange
  PSK - hex encoded (without starting 0x) shared key to be used for connection
  IDENTITY - name associated with the PSK key
  --ssl3 - enable support for SSLv3
  VER - TLS version as a string, "ssl3", "tls1.0", "tls1.1", "tls1.2" or
        "tls1.3"
  --tickets COUNT - how many tickets should server send after handshake is
                    finished
  --cipherlist - comma separated ciphers to enable. For ex. aes128ccm,3des
                 You can specify this option multiple times.
  --request-pha - ask client for post-handshake authentication
  --require-pha - abort connection if client didn't provide certificate in
                  post-handshake authentication
  CERT, KEY - the file with key and certificates that will be used by client or
        server. The server can accept multiple pairs of `-c` and `-k` options
        to configure different certificates (like RSA and ECDSA)

""")
    sys.exit(-1)


def ver_to_tuple(name):
    vers = {"ssl3": (3, 0),
            "tls1.0": (3, 1),
            "tls1.1": (3, 2),
            "tls1.2": (3, 3),
            "tls1.3": (3, 4)}
    try:
        return vers[name]
    except KeyError:
        raise ValueError("Unknown protocol name: {0}".format(name))


def printError(s):
    """Print error message and exit"""
    sys.stderr.write("ERROR: %s\n" % s)
    sys.exit(-1)


def handleArgs(argv, argString, flagsList=[]):
    # Convert to getopt argstring format:
    # Add ":" after each arg, ie "abc" -> "a:b:c:"
    getOptArgString = ":".join(argString) + ":"
    try:
        opts, argv = getopt.getopt(argv, getOptArgString, flagsList)
    except getopt.GetoptError as e:
        printError(e) 
    # Default values if arg not present  
    privateKey = None
    cert_chain = None
    virtual_hosts = []
    v_host_cert = None
    username = None
    password = None
    tacks = None
    verifierDB = None
    reqCert = False
    directory = None
    expLabel = None
    expLength = 20
    alpn = []
    dhparam = None
    psk = None
    psk_ident = None
    psk_hash = 'sha256'
    resumption = False
    ssl3 = False
    max_ver = None
    tickets = None
    ciphers = []
    request_pha = False
    require_pha = False

    for opt, arg in opts:
        if opt == "-k":
            s = open(arg, "rb").read()
            if sys.version_info[0] >= 3:
                s = str(s, 'utf-8')
            # OpenSSL/m2crypto does not support RSASSA-PSS certificates
            if not privateKey:
                privateKey = parsePEMKey(s, private=True,
                                         implementations=["python"])
            else:
                if not v_host_cert:
                    raise ValueError("Virtual host certificate missing "
                                     "(must be listed before key)")
                p_key = parsePEMKey(s, private=True,
                                    implementations=["python"])
                if not virtual_hosts:
                    virtual_hosts.append(VirtualHost())
                virtual_hosts[0].keys.append(
                    Keypair(p_key, v_host_cert.x509List))
                v_host_cert = None
        elif opt == "-c":
            s = open(arg, "rb").read()
            if sys.version_info[0] >= 3:
                s = str(s, 'utf-8')
            if not cert_chain:
                cert_chain = X509CertChain()
                cert_chain.parsePemList(s)
            else:
                v_host_cert = X509CertChain()
                v_host_cert.parsePemList(s)
        elif opt == "-u":
            username = arg
        elif opt == "-p":
            password = arg
        elif opt == "-t":
            if tackpyLoaded:
                s = open(arg, "rU").read()
                tacks = Tack.createFromPemList(s)
        elif opt == "-v":
            verifierDB = VerifierDB(arg)
            verifierDB.open()
        elif opt == "-d":
            directory = arg
        elif opt == "--reqcert":
            reqCert = True
        elif opt == "-l":
            expLabel = arg
        elif opt == "-L":
            expLength = int(arg)
        elif opt == "-a":
            alpn.append(bytearray(arg, 'utf-8'))
        elif opt == "--param":
            s = open(arg, "rb").read()
            if sys.version_info[0] >= 3:
                s = str(s, 'utf-8')
            dhparam = parseDH(s)
        elif opt == "--psk":
            psk = a2b_hex(arg)
        elif opt == "--psk-ident":
            psk_ident = bytearray(arg, 'utf-8')
        elif opt == "--psk-sha384":
            psk_hash = 'sha384'
        elif opt == "--resumption":
            resumption = True
        elif opt == "--ssl3":
            ssl3 = True
        elif opt == "--max-ver":
            max_ver = ver_to_tuple(arg)
        elif opt == "--tickets":
            tickets = int(arg)
        elif opt == "--cipherlist":
            ciphers.append(arg)
        elif opt == "--request-pha":
            request_pha = True
        elif opt == "--require-pha":
            require_pha = True
        else:
            assert(False)

    # when no names provided, don't return array
    if not alpn:
        alpn = None
    if (psk and not psk_ident) or (not psk and psk_ident):
        printError("PSK and IDENTITY must be set together")
    if not argv:
        printError("Missing address")
    if len(argv)>1:
        printError("Too many arguments")
    #Split address into hostname/port tuple
    address = argv[0]
    address = address.split(":")
    if len(address) != 2:
        raise SyntaxError("Must specify <host>:<port>")
    address = ( address[0], int(address[1]) )

    # Populate the return list
    retList = [address]
    if "k" in argString:
        retList.append(privateKey)
    if "c" in argString:
        retList.append(cert_chain)
        retList.append(virtual_hosts)
    if "u" in argString:
        retList.append(username)
    if "p" in argString:
        retList.append(password)
    if "t" in argString:
        retList.append(tacks)
    if "v" in argString:
        retList.append(verifierDB)
    if "d" in argString:
        retList.append(directory)
    if "reqcert" in flagsList:
        retList.append(reqCert)
    if "l" in argString:
        retList.append(expLabel)
    if "L" in argString:
        retList.append(expLength)
    if "a" in argString:
        retList.append(alpn)
    if "param=" in flagsList:
        retList.append(dhparam)
    if "psk=" in flagsList:
        retList.append(psk)
    if "psk-ident=" in flagsList:
        retList.append(psk_ident)
    if "psk-sha384" in flagsList:
        retList.append(psk_hash)
    if "resumption" in flagsList:
        retList.append(resumption)
    if "ssl3" in flagsList:
        retList.append(ssl3)
    if "max-ver=" in flagsList:
        retList.append(max_ver)
    if "tickets=" in flagsList:
        retList.append(tickets)
    if "cipherlist=" in flagsList:
        retList.append(ciphers)
    if "request-pha" in flagsList:
        retList.append(request_pha)
    if "require-pha" in flagsList:
        retList.append(require_pha)
    return retList


def printGoodConnection(connection, seconds):
    print("  Handshake time: %.3f seconds" % seconds)
    print("  Version: %s" % connection.getVersionName())
    print("  Cipher: %s %s" % (connection.getCipherName(), 
        connection.getCipherImplementation()))
    print("  Ciphersuite: {0}".\
            format(CipherSuite.ietfNames[connection.session.cipherSuite]))
    if connection.session.srpUsername:
        print("  Client SRP username: %s" % connection.session.srpUsername)
    if connection.session.clientCertChain:
        print("  Client X.509 SHA1 fingerprint: %s" % 
            connection.session.clientCertChain.getFingerprint())
    else:
        print("  No client certificate provided by peer")
    if connection.session.serverCertChain:
        print("  Server X.509 SHA1 fingerprint: %s" % 
            connection.session.serverCertChain.getFingerprint())
    if connection.version >= (3, 3) and connection.serverSigAlg is not None:
        scheme = SignatureScheme.toRepr(connection.serverSigAlg)
        if scheme is None:
            scheme = "{1}+{0}".format(
                HashAlgorithm.toStr(connection.serverSigAlg[0]),
                SignatureAlgorithm.toStr(connection.serverSigAlg[1]))
        print("  Key exchange signature: {0}".format(scheme))
    if connection.ecdhCurve is not None:
        print("  Group used for key exchange: {0}".format(\
                GroupName.toStr(connection.ecdhCurve)))
    if connection.dhGroupSize is not None:
        print("  DH group size: {0} bits".format(connection.dhGroupSize))
    if connection.session.serverName:
        print("  SNI: %s" % connection.session.serverName)
    if connection.session.tackExt:   
        if connection.session.tackInHelloExt:
            emptyStr = "\n  (via TLS Extension)"
        else:
            emptyStr = "\n  (via TACK Certificate)" 
        print("  TACK: %s" % emptyStr)
        print(str(connection.session.tackExt))
    if connection.session.appProto:
        print("  Application Layer Protocol negotiated: {0}".format(
            connection.session.appProto.decode('utf-8')))
    print("  Next-Protocol Negotiated: %s" % connection.next_proto) 
    print("  Encrypt-then-MAC: {0}".format(connection.encryptThenMAC))
    print("  Extended Master Secret: {0}".format(
                                               connection.extendedMasterSecret))

def printExporter(connection, expLabel, expLength):
    if expLabel is None:
        return
    expLabel = bytearray(expLabel, "utf-8")
    exp = connection.keyingMaterialExporter(expLabel, expLength)
    exp = b2a_hex(exp).upper()
    print("  Exporter label: {0}".format(expLabel))
    print("  Exporter length: {0}".format(expLength))
    print("  Keying material: {0}".format(exp))

    
def clientCmd(argv):
    (address, privateKey, cert_chain, virtual_hosts, username, password,
            expLabel,
            expLength, alpn, psk, psk_ident, psk_hash, resumption, ssl3,
            max_ver, cipherlist) = \
        handleArgs(argv, "kcuplLa", ["psk=", "psk-ident=", "psk-sha384",
                                     "resumption", "ssl3", "max-ver=",
                                     "cipherlist="])
        
    if (cert_chain and not privateKey) or (not cert_chain and privateKey):
        raise SyntaxError("Must specify CERT and KEY together")
    if (username and not password) or (not username and password):
        raise SyntaxError("Must specify USER with PASS")
    if cert_chain and username:
        raise SyntaxError("Can use SRP or client cert for auth, not both")
    if expLabel is not None and not expLabel:
        raise ValueError("Label must be non-empty")

    #Connect to server
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    sock.connect(address)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    connection = TLSConnection(sock)
    
    settings = HandshakeSettings()
    if psk:
        settings.pskConfigs = [(psk_ident, psk, psk_hash)]
    settings.useExperimentalTackExtension = True
    if ssl3:
        settings.minVersion = (3, 0)
    if max_ver:
        settings.maxVersion = max_ver
    if cipherlist:
        settings.cipherNames = [item for cipher in cipherlist
                                for item in cipher.split(',')]
    try:
        start = time_stamp()
        if username and password:
            connection.handshakeClientSRP(username, password, 
                settings=settings, serverName=address[0])
        else:
            connection.handshakeClientCert(cert_chain, privateKey,
                settings=settings, serverName=address[0], alpn=alpn)
        stop = time_stamp()
        print("Handshake success")        
    except TLSLocalAlert as a:
        if a.description == AlertDescription.user_canceled:
            print(str(a))
        else:
            raise
        sys.exit(-1)
    except TLSRemoteAlert as a:
        if a.description == AlertDescription.unknown_psk_identity:
            if username:
                print("Unknown username")
            else:
                raise
        elif a.description == AlertDescription.bad_record_mac:
            if username:
                print("Bad username or password")
            else:
                raise
        elif a.description == AlertDescription.handshake_failure:
            print("Unable to negotiate mutually acceptable parameters")
        else:
            raise
        sys.exit(-1)
    printGoodConnection(connection, stop-start)
    printExporter(connection, expLabel, expLength)
    session = connection.session
    connection.send(b"GET / HTTP/1.0\r\n\r\n")
    while True:
        try:
            r = connection.recv(10240)
            if not r:
                break
        except socket.timeout:
            break
        except TLSAbruptCloseError:
            break
    connection.close()
    # we're expecting an abrupt close error which marks the session as
    # unreasumable, override it
    session.resumable = True

    print("Received {0} ticket[s]".format(len(connection.tickets)))
    assert connection.tickets is session.tickets

    if not session.tickets:
        return

    if not resumption:
        return

    print("Trying resumption handshake")

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    sock.connect(address)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    connection = TLSConnection(sock)

    try:
        start = time_stamp()
        connection.handshakeClientCert(serverName=address[0], alpn=alpn,
            session=session)
        stop = time_stamp()
        print("Handshake success")
    except TLSLocalAlert as a:
        if a.description == AlertDescription.user_canceled:
            print(str(a))
        else:
            raise
        sys.exit(-1)
    except TLSRemoteAlert as a:
        if a.description == AlertDescription.unknown_psk_identity:
            if username:
                print("Unknown username")
            else:
                raise
        elif a.description == AlertDescription.bad_record_mac:
            if username:
                print("Bad username or password")
            else:
                raise
        elif a.description == AlertDescription.handshake_failure:
            print("Unable to negotiate mutually acceptable parameters")
        else:
            raise
        sys.exit(-1)
    printGoodConnection(connection, stop-start)
    printExporter(connection, expLabel, expLength)
    connection.close()


def serverCmd(argv):
    (address, privateKey, cert_chain, virtual_hosts, tacks, verifierDB,
            directory, reqCert,
            expLabel, expLength, dhparam, psk, psk_ident, psk_hash, ssl3,
            max_ver, tickets, cipherlist, request_pha, require_pha) = \
        handleArgs(argv, "kctbvdlL",
                   ["reqcert", "param=", "psk=",
                    "psk-ident=", "psk-sha384", "ssl3", "max-ver=",
                    "tickets=", "cipherlist=", "request-pha", "require-pha"])


    if (cert_chain and not privateKey) or (not cert_chain and privateKey):
        raise SyntaxError("Must specify CERT and KEY together")
    if tacks and not cert_chain:
        raise SyntaxError("Must specify CERT with Tacks")
    
    print("I am an HTTPS test server, I will listen on %s:%d" % 
            (address[0], address[1]))    
    if directory:
        os.chdir(directory)
    print("Serving files from %s" % os.getcwd())
    
    if cert_chain and privateKey:
        print("Using certificate and private key...")
    if verifierDB:
        print("Using verifier DB...")
    if tacks:
        print("Using Tacks...")
    if reqCert:
        print("Asking for client certificates...")
        
    #############
    sessionCache = SessionCache()
    username = None
    sni = None
    if is_valid_hostname(address[0]):
        sni = address[0]
    settings = HandshakeSettings()
    settings.useExperimentalTackExtension=True
    settings.dhParams = dhparam
    if tickets is not None:
        settings.ticket_count = tickets
    if psk:
        settings.pskConfigs = [(psk_ident, psk, psk_hash)]
    settings.ticketKeys = [getRandomBytes(32)]
    if ssl3:
        settings.minVersion = (3, 0)
    if max_ver:
        settings.maxVersion = max_ver
    settings.virtual_hosts = virtual_hosts
    if cipherlist:
        settings.cipherNames = [item for cipher in cipherlist
                                for item in cipher.split(',')]

    class MySimpleHTTPHandler(SimpleHTTPRequestHandler, object):
        """Buffer the header and body of HTTP message."""
        wbufsize = -1

        def do_GET(self):
            """Simple override to send KeyUpdate to client."""
            if self.path.startswith('/keyupdate'):
                for i in self.connection.send_keyupdate_request(
                        KeyUpdateMessageType.update_requested):
                    if i in (0, 1):
                        continue
                    else:
                        raise ValueError("Invalid return from "
                                         "send_keyupdate_request")
            if self.path.startswith('/secret') and not request_pha:
                try:
                    for i in self.connection.request_post_handshake_auth():
                        pass
                except ValueError:
                    self.wfile.write(b'HTTP/1.0 401 Certificate authentication'
                                     b' required\r\n')
                    self.wfile.write(b'Connection: close\r\n')
                    self.wfile.write(b'Content-Length: 0\r\n\r\n')
                    return
                self.connection.read(0, 0)
                if self.connection.session.clientCertChain:
                    print("   Got client certificate in post-handshake auth: "
                          "{0}".format(self.connection.session
                                       .clientCertChain.getFingerprint()))
                else:
                    print("   No certificate from client received")
                    self.wfile.write(b'HTTP/1.0 401 Certificate authentication'
                                     b' required\r\n')
                    self.wfile.write(b'Connection: close\r\n')
                    self.wfile.write(b'Content-Length: 0\r\n\r\n')
                    return
            return super(MySimpleHTTPHandler, self).do_GET()

    class MyHTTPServer(ThreadingMixIn, TLSSocketServerMixIn, HTTPServer):
        def handshake(self, connection):
            print("About to handshake...")
            activationFlags = 0
            if tacks:
                if len(tacks) == 1:
                    activationFlags = 1
                elif len(tacks) == 2:
                    activationFlags = 3

            try:
                start = time_stamp()
                connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY,
                                      1)
                connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER,
                                      struct.pack('ii', 1, 5))
                connection.client_cert_required = require_pha
                connection.handshakeServer(certChain=cert_chain,
                                              privateKey=privateKey,
                                              verifierDB=verifierDB,
                                              tacks=tacks,
                                              activationFlags=activationFlags,
                                              sessionCache=sessionCache,
                                              settings=settings,
                                              nextProtos=[b"http/1.1"],
                                              alpn=[bytearray(b'http/1.1')],
                                              reqCert=reqCert,
                                              sni=sni)
                                              # As an example (does not work here):
                                              #nextProtos=[b"spdy/3", b"spdy/2", b"http/1.1"])
                try:
                    if request_pha:
                        for i in connection.request_post_handshake_auth():
                            pass
                except ValueError:
                    # if we can't do PHA, we can't do it
                    pass
                stop = time_stamp()
            except TLSRemoteAlert as a:
                if a.description == AlertDescription.user_canceled:
                    print(str(a))
                    return False
                else:
                    raise
            except TLSLocalAlert as a:
                if a.description == AlertDescription.unknown_psk_identity:
                    if username:
                        print("Unknown username")
                        return False
                    else:
                        raise
                elif a.description == AlertDescription.bad_record_mac:
                    if username:
                        print("Bad username or password")
                        return False
                    else:
                        raise
                elif a.description == AlertDescription.handshake_failure:
                    print("Unable to negotiate mutually acceptable parameters")
                    return False
                else:
                    raise

            connection.ignoreAbruptClose = True
            printGoodConnection(connection, stop-start)
            printExporter(connection, expLabel, expLength)
            return True

    httpd = MyHTTPServer(address, MySimpleHTTPHandler)
    httpd.serve_forever()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        printUsage("Missing command")
    elif sys.argv[1] == "client"[:len(sys.argv[1])]:
        clientCmd(sys.argv[2:])
    elif sys.argv[1] == "server"[:len(sys.argv[1])]:
        serverCmd(sys.argv[2:])
    else:
        printUsage("Unknown command: %s" % sys.argv[1])


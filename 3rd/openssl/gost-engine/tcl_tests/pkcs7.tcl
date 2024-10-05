package require base64
if {[info exists env(TOOLDIR)]} {
	lappend auto_path $env(TOOLDIR)
} {
	lappend auto_path "[file dirname [info script]]/../../maketool"
}
package require asn 0.7.1

namespace eval pkcs7 {
	namespace import ::asn::*
	namespace export *

	proc asnTag {data_var} {
		upvar $data_var data
		asnPeekByte data b
		return $b
	}

	proc envelopedData {der} {
		asnGetSequence der seq0
		asnGetObjectIdentifier seq0 id_envelopedData
		if {$id_envelopedData != {1 2 840 113549 1 7 3}} {
			error "Waited id-envelopedData, got $id_envelopedData"
		}
		asnGetContext seq0 n envelopedData
		if {$n != 0} {
			error "Waited context 0, got $n"
		}
		asnGetSequence envelopedData envelopedData
		asnGetInteger envelopedData version
		set originatorInfo {}
		if {[asnTag envelopedData] != 0x31} {
			asnGetContext envelopedData tag originatorInfo
		}
		asnGetSet envelopedData recipientInfos
		asnGetSequence envelopedData encryptedContentInfo
		set unprotectedAttrs {}
		if {[string length $envelopedData]} {
			asnGetContext envelopedData tag unprotectedAttrs
		}
		return [list $version $originatorInfo $recipientInfos $encryptedContentInfo $unprotectedAttrs $envelopedData]
	}

	proc recipientInfos {rIs} {
		set result {}
		while {[string length $rIs]} {
			asnGetSequence rIs inf
			asnGetInteger inf version
			set tag {}
			if {[asnTag inf] == 0x30} {
				asnGetSequence inf rid
			} {
				asnGetContext inf tag rid
			}
			asnGetSequence inf keyEncAlg
			asnGetOctetString inf encryptedKey
			lappend result [list $version [list $tag $rid] $keyEncAlg $encryptedKey]
		}
		return $result
	}

	proc subjectPublicKeyInfo {spki} {
		asnGetSequence spki algorithmIdentifier
		asnGetBitString spki subjectPublicKey
		list $algorithmIdentifier $subjectPublicKey $spki
	}

	proc algorithmIdentifier {ai} {
		asnGetObjectIdentifier ai oid
		set param {}
		if {[string length $ai]} {
			asnGetSequence ai param
		}
		return [list $oid $param $ai]
	}

	proc algorithmParamPKGOST {param} {
		asnGetObjectIdentifier param pubkey_param
		asnGetObjectIdentifier param digest_param
		set cipher_param {}
		if {[string length $param]} {
			asnGetObjectIdentifier param cipher_param
		}
		return [list $pubkey_param $digest_param $cipher_param $param]
	}

	proc keyTransportGOST {octet_string} {
		asnGetSequence octet_string inf
		asnGetSequence inf encryptedKey
		set transportParams {}
		if {[string length $inf]} {
			asnGetContext inf tag transportParams
		}
		return [list $encryptedKey $transportParams $inf]
	}

	proc encryptedKeyGOST {encryptedKeyAndMAC} {
		asnGetOctetString encryptedKeyAndMAC encryptedKey
		asnGetOctetString encryptedKeyAndMAC MAC
		list $encryptedKey $MAC $encryptedKeyAndMAC
	}

	proc transportParameters {transportParams} {
		asnGetObjectIdentifier transportParams encryptionParamSet
		set ephemeralPublicKey {}
		if {[asnTag transportParams] == 0xa0} {
			asnGetContext transportParams tag ephemeralPublicKey
		}
		asnGetOctetString transportParams ukm
		list $encryptionParamSet $ephemeralPublicKey $ukm $transportParams
	}

	proc encryptedContentInfo {eci} {
		asnGetObjectIdentifier eci oid
		asnGetSequence eci algorithmIdentifier
		set encryptedContent {}
		if {[string length $eci]} {
			asnGetContext eci tag encryptedContent
		}
		list $oid $algorithmIdentifier $encryptedContent $eci
	}

	proc algorithmParamEncGOST {param} {
		asnGetOctetString param ukm
		asnGetObjectIdentifier param encParam
		list $ukm $encParam $param
	}

	proc algorithm_oids_from_envelopedData {der} {
		set result {}
		foreach {v oI rIs eCI uAs t} [envelopedData $der] {
			# recipient infos
			set rin 0
			foreach rI [recipientInfos $rIs] {
				foreach {v rid kEA eK} $rI {
					# export (pubkey) algorithm identifier
					foreach {pk_oid param t} [algorithmIdentifier $kEA] {
						lappend result ri${rin}:kea=[join $pk_oid .]
						foreach {pkp dp cp t} [algorithmParamPKGOST $param] {
							lappend result \
								ri${rin}:kea:pkp=[join $pkp .] \
								ri${rin}:kea:dp=[join $dp .] \
								ri${rin}:kea:cp=[join $cp .]
						}
					}
					# encryptedKey encapsulated structure
					foreach {eK tPs t} [keyTransportGOST $eK] {
						# transport parameters
						foreach {ePS ePK ukm t} [transportParameters $tPs] {
							# encryption paramset
							lappend result ri${rin}:ktcp=[join $ePS .]
							# ephemeral public key
							if {[string length $ePK]} {
								foreach {aI sPK t} [subjectPublicKeyInfo $ePK] {
									# algorithm identifier
									foreach {pKI param t} [algorithmIdentifier $aI] {
										lappend result ri${rin}:ktepk=[join $pKI .]
										foreach {pkp dp cp t} [algorithmParamPKGOST $param] {
											lappend result \
												ri${rin}:ktepk:pkp=[join $pkp .] \
												ri${rin}:ktepk:dp=[join $dp .] \
												ri${rin}:ktepk:cp=[join $cp .]
										}
									}
								}
							}
						}
					}
				}
				incr rin
			}
			foreach {oid aI eC t} [encryptedContentInfo $eCI] {
				# algorithm identifier
				foreach {oid param t} [algorithmIdentifier $aI] {
					lappend result ea=[join $oid .]
					foreach {ukm oid t} [algorithmParamEncGOST $param] {
						lappend result ea:cp=[join $oid .]
					}
				}
			}
		}
		return $result
	}

}

package provide pkcs7 0.1
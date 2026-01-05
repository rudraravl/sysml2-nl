package MedicalDeviceHijackSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def EncryptionLevel {
		attribute strength : Integer;
		attribute algorithm : String;
	}
	
	attribute def AuthenticationCredential {
		attribute credentialID : String;
		attribute validUntil : Real;
		attribute isRevoked : Boolean;
	}
	
	item def CommandMessage {
		attribute messageID : String;
		attribute timestamp : Real;
		attribute payload : String;
		attribute signature : String;
		attribute isAuthenticated : Boolean;
	}
	
	item def TherapyParameters {
		attribute dosageRate : Real;
		attribute duration : Real;
		attribute concentration : Real;
	}
	
	item def SecurityAlert {
		attribute alertID : String;
		attribute severity : Integer;
		attribute description : String;
		attribute detectedAt : Real;
	}
	
	port def SecureCommunicationPort {
		in item incomingMessage : CommandMessage;
		out item outgoingMessage : CommandMessage;
		out item securityAlert : SecurityAlert;
	}
	
	port def TherapyPort {
		in item therapyCommand : TherapyParameters;
		out attribute deliveryStatus : Real;
	}
	
	port def MonitoringPort {
		out attribute vitalSign : Real;
		in attribute alertThreshold : Real;
	}
	
	part def InfusionPump {
		attribute pumpID : String;
		attribute firmwareVersion : String;
		attribute operationalState : String;
		
		port commPort : SecureCommunicationPort;
		port therapyDelivery : TherapyPort;
		port patientMonitor : MonitoringPort;
		
		part securityModule {
			attribute currentEncryption : EncryptionLevel;
			attribute trustedCredentials : AuthenticationCredential[*];
			
			event occurrence authenticationFailure;
			event occurrence encryptionBreach;
			event occurrence unauthorizedCommand;
			
			action def ValidateCommand {
				in command : CommandMessage;
				out isValid : Boolean;
				out alert : SecurityAlert;
			}
			
			action def EncryptCommunication {
				in plainMessage : CommandMessage;
				out encryptedMessage : CommandMessage;
			}
			
			action def DecryptCommunication {
				in encryptedMessage : CommandMessage;
				out plainMessage : CommandMessage;
			}
			
			perform action validate : ValidateCommand;
		}
		
		part therapyEngine {
			attribute activeParameters : TherapyParameters;
			attribute deliveredVolume : Real;
			attribute isDelivering : Boolean;
			
			action def ExecuteTherapy {
				in params : TherapyParameters;
				in authorized : Boolean;
				out deliveryRate : Real;
			}
			
			action def HaltTherapy {
				out status : String;
			}
			
			perform action execute : ExecuteTherapy;
		}
		
		part anomalyDetector {
			attribute baselinePattern : Real[*];
			attribute currentPattern : Real[*];
			attribute anomalyScore : Real;
			
			event occurrence anomalyDetected;
			event occurrence patternDeviation;
			
			action def AnalyzeTraffic {
				in messageStream : CommandMessage[*];
				out threatScore : Real;
			}
			
			perform action analyze : AnalyzeTraffic;
		}
		
		part auditLogger {
			attribute logBuffer : String[*];
			attribute logCapacity : Integer;
			
			action def RecordEvent {
				in eventType : String;
				in eventData : String;
				in timestamp : Real;
			}
			
			perform action record : RecordEvent;
		}
		
		exhibit state pumpBehavior {
			entry; then Initializing;
			
			state Initializing;
			accept at Initializing then Standby;
			
			state Standby;
			accept commandReceived at Standby then Authenticating;
			
			state Authenticating;
			accept authenticated at Authenticating then Delivering;
			accept authenticationFailed at Authenticating then Alarming;
			
			state Delivering;
			accept therapyComplete at Delivering then Standby;
			
			state Alarming;
			accept criticalThreat at Alarming then Lockdown;
			
			state Lockdown;
			accept systemReset at Lockdown then Standby;
		}
	}
	
	part def AttackerEntity {
		attribute attackerID : String;
		attribute sophisticationLevel : Integer;
		
		port attackVector : SecureCommunicationPort;
		
		part exploitFramework {
			attribute knownExploits : String[*];
			attribute targetVulnerabilities : String[*];
			
			action def CraftMaliciousCommand {
				in targetDevice : String;
				in exploitType : String;
				out maliciousMessage : CommandMessage;
			}
			
			perform action craft : CraftMaliciousCommand;
		}
		
		part commandInjector {
			attribute injectionRate : Real;
			attribute successfulInjections : Integer;
			
			action def InjectCommand {
				in maliciousCommand : CommandMessage;
				out injectionSuccess : Boolean;
			}
			
			perform action inject : InjectCommand;
		}
		
		event occurrence initiateAttack;
		event occurrence bypassSecurity;
		event occurrence gainControl;
		event occurrence manipulateTherapy;
	}
	
	part def Patient {
		attribute patientID : String;
		attribute medicalCondition : String;
		
		port deviceInterface : MonitoringPort;
		
		event occurrence receivesTherapy;
		event occurrence receivesIncorrectDosage;
		event occurrence experiencesHarm;
		event occurrence conditionWorsens;
	}
	
	part def HealthcareNetwork {
		attribute networkID : String;
		attribute securityPosture : EncryptionLevel;
		
		part networkFirewall {
			attribute ruleSet : String[*];
			attribute blockedAddresses : String[*];
		}
		
		part intrusionPreventionSystem {
			attribute detectionRules : String[*];
			attribute blockedAttempts : Integer;
		}
	}
	
	part def ClinicalWorkstation {
		attribute workstationID : String;
		attribute authorizedUser : String;
		
		port deviceControl : SecureCommunicationPort;
		
		action def IssueTherapyCommand {
			in parameters : TherapyParameters;
			in credentials : AuthenticationCredential;
			out command : CommandMessage;
		}
		
		perform action issueCommand : IssueTherapyCommand;
	}
	
	part hijackScenario {
		part pump : InfusionPump;
		part attacker : AttackerEntity;
		part patient : Patient;
		part network : HealthcareNetwork;
		part workstation : ClinicalWorkstation;
		
		connection legitimateControl connect workstation.deviceControl to pump.commPort;
		connection attackPath connect attacker.attackVector to pump.commPort;
		connection patientConnection connect pump.patientMonitor to patient.deviceInterface;
		
		action def HijackAttackSequence {
			first start;
			
			then action reconnaissance {
				doc /* Attacker scans network to identify vulnerable infusion pump */
			}
			
			then action identifyVulnerability {
				doc /* Attacker discovers weak authentication or unpatched firmware */
			}
			
			then action craftExploit : attacker.exploitFramework.craft {
				in targetDevice = pump.pumpID;
				in exploitType = "authentication_bypass";
				out maliciousMessage;
			}
			
			then action attemptInjection : attacker.commandInjector.inject {
				in maliciousCommand = craftExploit.maliciousMessage;
				out injectionSuccess;
			}
			
			then decide;
				if pump.securityModule.validate.isValid == false then detectedAndBlocked;
				if attemptInjection.injectionSuccess == true then proceedWithHijack;
			
			action detectedAndBlocked {
				doc /* Security module detects attack and triggers lockdown */
			}
			then action generateAlert {
				doc /* System generates security alert and logs incident */
			}
			then done;
			
			action proceedWithHijack;
			then action gainDeviceControl {
				doc /* Attacker successfully bypasses authentication */
			}
			
			then action modifyTherapyParameters {
				doc /* Attacker alters dosage rate or therapy duration */
			}
			
			then action executeUnauthorizedTherapy : pump.therapyEngine.execute {
				in params {
					attribute dosageRate = 500.0;
					attribute duration = 2.0;
					attribute concentration = 10.0;
				}
				in authorized = false;
				out deliveryRate;
			}
			
			then action patientReceivesAlteredTherapy {
				doc /* Patient receives incorrect medication dosage */
			}
			
			then action adversePatientOutcome {
				doc /* Patient experiences adverse health effects */
			}
			
			then done;
		}
		
		perform action hijackAttack : HijackAttackSequence;
	}
	
	requirement def SecurityRequirement {
		doc /* Security requirements for medical device protection against hijacking */
		subject device : InfusionPump;
	}
	
	requirement <'SEC-101'> strongAuthentication : SecurityRequirement {
		doc /* Device shall implement multi-factor authentication for all command inputs */
		require constraint {
			device.securityModule.validate.isValid == true
		}
	}
	
	requirement <'SEC-102'> encryptedCommunication : SecurityRequirement {
		doc /* All network communications shall use AES-256 encryption minimum */
		require constraint {
			device.securityModule.currentEncryption.strength >= 256
		}
	}
	
	requirement <'SEC-103'> anomalyDetection : SecurityRequirement {
		doc /* Device shall continuously monitor for anomalous command patterns */
		require constraint {
			device.anomalyDetector.analyze.threatScore < 0.8
		}
	}
	
	requirement <'SEC-104'> commandValidation : SecurityRequirement {
		doc /* Device shall validate cryptographic signatures on all therapy commands */
		require constraint {
			device.securityModule.validate.isValid implies 
			device.therapyEngine.execute.authorized == true
		}
	}
	
	requirement <'SEC-105'> auditTrail : SecurityRequirement {
		doc /* Device shall maintain tamper-proof audit log of all commands and events */
		require constraint {
			device.auditLogger.logCapacity > 0
		}
	}
	
	requirement <'SAF-201'> patientSafety {
		doc /* System shall prevent patient harm from unauthorized device manipulation */
		subject patient : Patient;
		
		assume constraint attackerPresent {
			hijackScenario.attacker.sophisticationLevel > 0
		}
		
		require constraint preventHarm {
			not (patient.receivesIncorrectDosage and patient.experiencesHarm)
		}
	}
	
	requirement <'SAF-202'> failsafeOperation {
		doc /* Device shall enter safe state upon detection of security breach */
		subject device : InfusionPump;
		
		require constraint {
			device.securityModule.unauthorizedCommand
		}
	}
	
	requirement <'SYS-001'> systemPrimaryFunction {
		doc /* The medical device hijack system demonstrates how networked infusion 
		       pumps can be compromised by malicious actors who exploit weak 
		       authentication, unencrypted communications, or firmware vulnerabilities 
		       to gain unauthorized control and manipulate therapy delivery parameters, 
		       potentially causing patient harm through incorrect medication dosages. 
		       The system models attack vectors, security countermeasures, detection 
		       mechanisms, and patient safety impacts to inform secure medical device 
		       design and deployment practices. */
		
		subject hijackScenario;
		
		require strongAuthentication;
		require encryptedCommunication;
		require anomalyDetection;
		require commandValidation;
		require auditTrail;
		require patientSafety;
		require failsafeOperation;
	}
}

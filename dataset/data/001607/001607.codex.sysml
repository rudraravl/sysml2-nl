package TranshumanAdaptiveAugmentationSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Percent {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def Millisecond {
        :> ScalarValues::Real;
        unit = "ms";
    }

    attribute def Millivolt {
        :> ScalarValues::Real;
        unit = "mV";
    }

    attribute def Micrometer {
        :> ScalarValues::Real;
        unit = "um";
    }

    attribute def Celsius {
        :> ScalarValues::Real;
        unit = "degC";
    }

    attribute def Watt {
        :> ScalarValues::Real;
        unit = "W";
    }

    attribute def GigabitPerSecond {
        :> ScalarValues::Real;
        unit = "Gbps";
    }

    attribute def AuthenticationStrength {
        :> ScalarValues::Integer;
        range = 0..10;
    }

    item def NeuralSignal {
        attribute amplitude : Millivolt;
        attribute frequencyHz : Real;
        attribute confidence : Percent;
        attribute sourceRegion : String;
    }

    item def MotorIntent {
        attribute targetEffector : String;
        attribute activationLevel : Percent;
        attribute latencyBudget : Millisecond;
    }

    item def SensoryFeedback {
        attribute modality : String;
        attribute intensity : Percent;
        attribute encodedResolution : Percent;
        attribute safeForUser : Boolean;
    }

    item def CognitiveAssistRequest {
        attribute objective : String;
        attribute urgency : Percent;
        attribute privacyLevel : AuthenticationStrength;
    }

    item def CognitiveAssistResponse {
        attribute recommendation : String;
        attribute confidence : Percent;
        attribute explanationSummary : String;
    }

    item def BiometricIdentityToken {
        attribute subjectId : String;
        attribute livenessScore : Percent;
        attribute cryptoStrength : AuthenticationStrength;
    }

    item def SystemHealthReport {
        attribute implantTemperature : Celsius;
        attribute batteryCharge : Percent;
        attribute neuralInterfaceIntegrity : Percent;
        attribute actuatorIntegrity : Percent;
        attribute safetyModeActive : Boolean;
    }

    item def EncryptedTelemetry {
        attribute payloadType : String;
        attribute encryptionLevel : AuthenticationStrength;
        attribute bandwidth : GigabitPerSecond;
    }

    part def HumanUser {
        attribute userId : String;
        attribute consentGranted : Boolean;
        attribute fatigueLevel : Percent;
        attribute neurologicalStress : Percent;

        port neuralOut : out NeuralSignal;
        port sensoryIn : in SensoryFeedback;
        port biometricOut : out BiometricIdentityToken;
        port intentOut : out MotorIntent;
        port assistRequestOut : out CognitiveAssistRequest;
        port assistResponseIn : in CognitiveAssistResponse;
    }

    part def NeuralInterfaceArray {
        attribute electrodeSpacing : Micrometer = 40.0;
        attribute samplingRateHz : Real = 48000.0;
        attribute signalQuality : Percent;
        attribute stimulationEnabled : Boolean;

        port rawNeuralIn : in NeuralSignal;
        port decodedIntentOut : out MotorIntent;
        port sensoryFeedbackIn : in SensoryFeedback;
        port stimulationOut : out SensoryFeedback;
        port healthOut : out SystemHealthReport;
    }

    part def BioCyberneticCore {
        attribute processorLoad : Percent;
        attribute inferenceConfidence : Percent;
        attribute responseLatency : Millisecond;
        attribute privacyModeEnabled : Boolean;

        port intentIn : in MotorIntent;
        port assistRequestIn : in CognitiveAssistRequest;
        port assistResponseOut : out CognitiveAssistResponse;
        port actuatorCommandOut : out MotorIntent;
        port sensoryFeedbackOut : out SensoryFeedback;
        port telemetryOut : out EncryptedTelemetry;
        port healthIn : in SystemHealthReport;
    }

    part def AugmentedLimbActuator {
        attribute maxGripForceN : Real = 420.0;
        attribute jointAccuracyDeg : Real = 0.25;
        attribute powerDraw : Watt;
        attribute enabled : Boolean;

        port commandIn : in MotorIntent;
        port tactileFeedbackOut : out SensoryFeedback;
        port healthOut : out SystemHealthReport;
    }

    part def SensoryExpansionModule {
        attribute infraredSensitivity : Percent;
        attribute ultrasonicSensitivity : Percent;
        attribute hapticResolution : Percent;

        port environmentalInput : in SensoryFeedback;
        port encodedFeedbackOut : out SensoryFeedback;
    }

    part def IdentityAndConsentGuard {
        attribute minimumAuthenticationStrength : AuthenticationStrength = 8;
        attribute consentValid : Boolean;
        attribute emergencyOverrideActive : Boolean;

        port biometricIn : in BiometricIdentityToken;
        port assistRequestIn : in CognitiveAssistRequest;
        port authorizationOut : out BiometricIdentityToken;
    }

    part def PowerAndThermalManager {
        attribute batteryCharge : Percent;
        attribute implantTemperature : Celsius;
        attribute maxSafeTemperature : Celsius = 39.5;
        attribute reservePowerAvailable : Boolean;

        port healthIn : in SystemHealthReport;
        port powerStatusOut : out SystemHealthReport;
    }

    part def SecureExternalGateway {
        attribute connected : Boolean;
        attribute encryptionStrength : AuthenticationStrength = 9;
        attribute dataRate : GigabitPerSecond;

        port telemetryIn : in EncryptedTelemetry;
        port assistResponseIn : in CognitiveAssistResponse;
        port assistRequestOut : out CognitiveAssistRequest;
    }

    action def DecodeNeuralIntent {
        in rawSignal : NeuralSignal;
        out decodedIntent : MotorIntent;
    }

    action def AuthorizeAugmentationUse {
        in identity : BiometricIdentityToken;
        in requestedPrivacyLevel : AuthenticationStrength;
        out authorized : Boolean;
    }

    action def GenerateCognitiveAssistance {
        in request : CognitiveAssistRequest;
        out response : CognitiveAssistResponse;
    }

    action def EncodeSensoryFeedback {
        in environmentalSignal : SensoryFeedback;
        out neuralFeedback : SensoryFeedback;
    }

    action def ApplySafetyLimits {
        in health : SystemHealthReport;
        in proposedIntent : MotorIntent;
        out limitedIntent : MotorIntent;
    }

    action def ExecuteAugmentedMotion {
        in command : MotorIntent;
        out tactileFeedback : SensoryFeedback;
    }

    state def AugmentationOperationalState {
        entry action InitializeSecureBoot;
        state Offline;
        state IdentityVerification;
        state ConsentValidation;
        state Calibration;
        state Augmenting;
        state CognitiveAssist;
        state SafetyLimited;
        state EmergencyShutdown;

        transition first Offline;
        transition Offline to IdentityVerification
            accept BiometricIdentityToken;

        transition IdentityVerification to ConsentValidation
            if identity.cryptoStrength >= 8 and identity.livenessScore >= 95.0;

        transition ConsentValidation to Calibration
            if user.consentGranted == true;

        transition Calibration to Augmenting
            if neuralInterface.signalQuality >= 90.0;

        transition Augmenting to CognitiveAssist
            accept CognitiveAssistRequest
            if request.privacyLevel <= 8;

        transition CognitiveAssist to Augmenting
            after 200 ms;

        transition Augmenting to SafetyLimited
            if health.implantTemperature > 39.5 or health.batteryCharge < 12.0;

        transition SafetyLimited to Augmenting
            if health.implantTemperature <= 38.0 and health.batteryCharge >= 20.0;

        transition Augmenting to EmergencyShutdown
            if health.neuralInterfaceIntegrity < 60.0 or user.neurologicalStress > 85.0;

        transition SafetyLimited to EmergencyShutdown
            if health.actuatorIntegrity < 50.0;

        transition EmergencyShutdown to Offline
            after 5 s;
    }

    part def TranshumanAdaptiveAugmentationSystem {
        doc /* Primary function: integrate human neural intent, secure identity, cognitive assistance, synthetic actuation, and expanded sensory feedback to enhance human capability while preserving consent, safety, privacy, and biological stability. */

        attribute systemAvailability : Percent;
        attribute endToEndLatency : Millisecond;
        attribute enhancementLevel : Percent;
        attribute safeOperatingMode : Boolean;

        part user : HumanUser;
        part neuralInterface : NeuralInterfaceArray;
        part core : BioCyberneticCore;
        part limb : AugmentedLimbActuator;
        part sensoryExpansion : SensoryExpansionModule;
        part consentGuard : IdentityAndConsentGuard;
        part powerThermal : PowerAndThermalManager;
        part gateway : SecureExternalGateway;

        port externalEnvironmentIn : in SensoryFeedback;
        port externalCloudAssistIn : in CognitiveAssistResponse;
        port externalTelemetryOut : out EncryptedTelemetry;

        connect user.neuralOut to neuralInterface.rawNeuralIn;
        connect neuralInterface.decodedIntentOut to core.intentIn;
        connect core.actuatorCommandOut to limb.commandIn;
        connect limb.tactileFeedbackOut to neuralInterface.sensoryFeedbackIn;
        connect neuralInterface.stimulationOut to user.sensoryIn;

        connect externalEnvironmentIn to sensoryExpansion.environmentalInput;
        connect sensoryExpansion.encodedFeedbackOut to core.sensoryFeedbackOut;
        connect core.sensoryFeedbackOut to neuralInterface.sensoryFeedbackIn;

        connect user.biometricOut to consentGuard.biometricIn;
        connect user.assistRequestOut to consentGuard.assistRequestIn;
        connect user.assistRequestOut to core.assistRequestIn;
        connect core.assistResponseOut to user.assistResponseIn;

        connect neuralInterface.healthOut to powerThermal.healthIn;
        connect limb.healthOut to powerThermal.healthIn;
        connect powerThermal.powerStatusOut to core.healthIn;

        connect core.telemetryOut to gateway.telemetryIn;
        connect core.telemetryOut to externalTelemetryOut;
        connect externalCloudAssistIn to gateway.assistResponseIn;
        connect gateway.assistRequestOut to core.assistRequestIn;

        perform action DecodeIntent {
            in rawSignal = user.neuralOut;
            out decodedIntent = neuralInterface.decodedIntentOut;
        }

        perform action VerifyConsent {
            in identity = user.biometricOut;
            in requestedPrivacyLevel = user.assistRequestOut.privacyLevel;
            out authorized = consentGuard.consentValid;
        }

        perform action AssistCognition {
            in request = user.assistRequestOut;
            out response = core.assistResponseOut;
        }

        perform action TranslateEnvironment {
            in environmentalSignal = externalEnvironmentIn;
            out neuralFeedback = sensoryExpansion.encodedFeedbackOut;
        }

        perform action LimitUnsafeCommand {
            in health = powerThermal.powerStatusOut;
            in proposedIntent = core.intentIn;
            out limitedIntent = core.actuatorCommandOut;
        }

        perform action MoveAugmentedLimb {
            in command = core.actuatorCommandOut;
            out tactileFeedback = limb.tactileFeedbackOut;
        }

        exhibit state AugmentationOperationalState;
    }

    requirement def ConsentRequirement {
        doc /* The system shall enable augmentation functions only when the human user has provided current explicit consent and biometric identity verification succeeds. */
        subject system : TranshumanAdaptiveAugmentationSystem;
        require constraint {
            system.consentGuard.consentValid == true and
            system.user.consentGranted == true
        }
    }

    requirement def NeuralLatencyRequirement {
        doc /* The system shall convert neural motor intent into actuator command output within a latency suitable for natural limb control. */
        subject system : TranshumanAdaptiveAugmentationSystem;
        require constraint {
            system.endToEndLatency <= 20.0
        }
    }

    requirement def SafetyThermalRequirement {
        doc /* The system shall enter safety-limited operation when implant temperature exceeds the maximum safe biological threshold. */
        subject system : TranshumanAdaptiveAugmentationSystem;
        require constraint {
            system.powerThermal.implantTemperature <= system.powerThermal.maxSafeTemperature or
            system.safeOperatingMode == true
        }
    }

    requirement def PrivacyRequirement {
        doc /* The system shall transmit external telemetry only as encrypted data with strong authentication and privacy protection. */
        subject system : TranshumanAdaptiveAugmentationSystem;
        require constraint {
            system.gateway.encryptionStrength >= 8
        }
    }

    requirement def SensoryFeedbackRequirement {
        doc /* The system shall provide encoded sensory feedback to the user whenever augmented actuation or environmental sensing is active. */
        subject system : TranshumanAdaptiveAugmentationSystem;
        require constraint {
            system.sensoryExpansion.hapticResolution >= 85.0 and
            system.neuralInterface.stimulationEnabled == true
        }
    }

    requirement def HumanStabilityRequirement {
        doc /* The system shall reduce or suspend augmentation when neurological stress exceeds safe operating limits. */
        subject system : TranshumanAdaptiveAugmentationSystem;
        require constraint {
            system.user.neurologicalStress <= 85.0 or
            system.safeOperatingMode == true
        }
    }

}
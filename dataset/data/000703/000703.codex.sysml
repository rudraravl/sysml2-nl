package NasalEPAPSystemModel {

    import ScalarValues::*;
    import Quantities::*;
    import ISQ::*;

    /* Value and item definitions */

    enum def BreathingPhase {
        inspiration;
        expiration;
        pause;
    }

    enum def TherapyMode {
        passiveExpiratoryResistance;
        bypassDuringInspiration;
        sealedStorage;
        faultRelief;
    }

    enum def DeviceStateKind {
        packaged;
        fitted;
        inhaleOpen;
        exhaleResisting;
        reliefOpen;
        removed;
        fault;
    }

    attribute def Pressure {
        :>> unit = "cmH2O";
    }

    attribute def FlowRate {
        :>> unit = "L/min";
    }

    attribute def Resistance {
        :>> unit = "cmH2O/(L/min)";
    }

    attribute def Area {
        :>> unit = "mm^2";
    }

    attribute def Force {
        :>> unit = "N";
    }

    attribute def Duration {
        :>> unit = "s";
    }

    attribute def LeakageRate {
        :>> unit = "L/min";
    }

    item def AmbientAir {
        attribute oxygenFraction : Real = 0.209;
        attribute humidityRelative : Real;
        attribute temperatureC : Real;
    }

    item def InspiredAir :> AmbientAir {
        attribute deliveredFlow : FlowRate;
        attribute inspiratoryPressureDrop : Pressure;
    }

    item def ExpiredAir {
        attribute carbonDioxideFraction : Real;
        attribute moistureFraction : Real;
        attribute expiratoryFlow : FlowRate;
        attribute expiratoryBackPressure : Pressure;
    }

    item def NasalPressureSignal {
        attribute pressure : Pressure;
        attribute phase : BreathingPhase;
    }

    item def FitStatus {
        attribute leak : LeakageRate;
        attribute sealStable : Boolean;
        attribute nostrilContactForce : Force;
    }

    item def TherapyEffect {
        attribute generatedEPAP : Pressure;
        attribute airwayStentingSupport : Real;
        attribute comfortIndex : Real;
    }

    port def AirPort {
        in item airIn : AmbientAir;
        out item airOut : ExpiredAir;
    }

    port def NasalInterfacePort {
        out item inspiredAir : InspiredAir;
        in item expiredAir : ExpiredAir;
        out item pressureSignal : NasalPressureSignal;
    }

    port def StatusPort {
        out item fitStatus : FitStatus;
        out item therapyEffect : TherapyEffect;
    }

    port def ReliefVentPort {
        out item ventedExpiredAir : ExpiredAir;
    }

    /* Part definitions */

    part def NasalEPAPSystem {
        attribute primaryFunction : String =
            "Provide passive expiratory positive airway pressure by allowing low-resistance nasal inspiration and imposing controlled resistance during nasal expiration to maintain upper-airway patency during sleep.";

        attribute targetEPAP : Pressure = 8.0;
        attribute maxSafeNasalPressure : Pressure = 20.0;
        attribute nominalInspiratoryDrop : Pressure = 0.8;
        attribute maximumLeakage : LeakageRate = 6.0;
        attribute intendedUseDuration : Duration = 28800.0;

        port environmentPort : AirPort;
        port patientPort : NasalInterfacePort;
        port statusPort : StatusPort;
        port reliefPort : ReliefVentPort;

        part leftNasalModule : NasalValveModule {
            attribute nostrilSide : String = "left";
        }

        part rightNasalModule : NasalValveModule {
            attribute nostrilSide : String = "right";
        }

        part bridge : FlexibleBridge {
            attribute bridgeSpan : Length = 24.0 [mm];
        }

        part adhesiveSeal : SkinAdhesiveSeal {
            attribute sealContactArea : Area = 420.0;
        }

        part pressureRelief : OverPressureRelief {
            attribute reliefCrackPressure : Pressure = 18.0;
        }

        part packaging : HygienicPackage {
            attribute sterileBarrierIntact : Boolean = true;
        }

        connect environmentPort to leftNasalModule.ambientPort;
        connect environmentPort to rightNasalModule.ambientPort;
        connect leftNasalModule.nasalPort to patientPort;
        connect rightNasalModule.nasalPort to patientPort;
        connect leftNasalModule.reliefInterface to pressureRelief.moduleInterface;
        connect rightNasalModule.reliefInterface to pressureRelief.moduleInterface;
        connect pressureRelief.ventPort to reliefPort;
        connect adhesiveSeal.leftSealInterface to leftNasalModule.sealInterface;
        connect adhesiveSeal.rightSealInterface to rightNasalModule.sealInterface;
        connect bridge.leftMount to leftNasalModule.bridgeMount;
        connect bridge.rightMount to rightNasalModule.bridgeMount;
        connect statusPort to adhesiveSeal.statusPort;

        action performTherapy {
            in item ambient : AmbientAir;
            in item expired : ExpiredAir;
            out item inspired : InspiredAir;
            out item effect : TherapyEffect;

            first start;
            then fitDevice;
            then supportInspiration;
            then resistExpiration;
            then monitorPressure;
            then finish;

            action fitDevice {
                out item fit : FitStatus;
            }

            action supportInspiration {
                in item ambientAir : AmbientAir;
                out item nasalAir : InspiredAir;
            }

            action resistExpiration {
                in item expiratoryAir : ExpiredAir;
                out item pressurizedExpiredAir : ExpiredAir;
                out item generatedEffect : TherapyEffect;
            }

            action monitorPressure {
                in item nasalPressure : NasalPressureSignal;
                out item reliefCommand : Boolean;
            }
        }

        state therapyStateMachine {
            state Packaged;
            state Fitted;
            state InspirationBypass;
            state ExpirationResistance;
            state ReliefVenting;
            state Removed;
            state Fault;

            entry;
            then Packaged;

            transition Packaged_to_Fitted
                first Packaged
                accept fittedByUser
                if packaging.sterileBarrierIntact
                then Fitted;

            transition Fitted_to_Inspiration
                first Fitted
                accept nasalPressureSignal
                if patientPort.pressureSignal.phase == BreathingPhase::inspiration
                then InspirationBypass;

            transition Inspiration_to_Expiration
                first InspirationBypass
                accept nasalPressureSignal
                if patientPort.pressureSignal.phase == BreathingPhase::expiration
                then ExpirationResistance;

            transition Expiration_to_Inspiration
                first ExpirationResistance
                accept nasalPressureSignal
                if patientPort.pressureSignal.phase == BreathingPhase::inspiration
                then InspirationBypass;

            transition Expiration_to_Relief
                first ExpirationResistance
                accept overPressureDetected
                if patientPort.pressureSignal.pressure > maxSafeNasalPressure
                then ReliefVenting;

            transition Relief_to_Fitted
                first ReliefVenting
                accept pressureNormalized
                if patientPort.pressureSignal.pressure <= targetEPAP
                then Fitted;

            transition Any_to_Removed
                first Fitted
                accept removedByUser
                then Removed;

            transition Leak_to_Fault
                first Fitted
                accept excessiveLeakDetected
                if adhesiveSeal.measuredLeakage > maximumLeakage
                then Fault;
        }
    }

    part def NasalValveModule {
        attribute nostrilSide : String;
        attribute inspiratoryValveArea : Area = 56.0;
        attribute expiratoryOrificeArea : Area = 4.2;
        attribute expiratoryResistance : Resistance = 1.0;
        attribute inhalationOpeningPressure : Pressure = 0.4;
        attribute expectedGeneratedEPAP : Pressure = 8.0;

        port ambientPort : AirPort;
        port nasalPort : NasalInterfacePort;
        port reliefInterface : AirPort;
        port sealInterface : StatusPort;
        port bridgeMount : StatusPort;

        part inspiratoryFlap : OneWayInspiratoryValve;
        part expiratoryResistor : MicroOrificeArray;
        part nasalInsert : SoftNasalCushion;
        part antiOcclusionGrid : ProtectiveGrid;

        connect ambientPort to inspiratoryFlap.upstreamPort;
        connect inspiratoryFlap.downstreamPort to nasalPort;
        connect nasalPort to expiratoryResistor.upstreamPort;
        connect expiratoryResistor.downstreamPort to ambientPort;
        connect expiratoryResistor.downstreamPort to reliefInterface;
        connect nasalInsert.patientSide to nasalPort;
        connect nasalInsert.sealStatus to sealInterface;
    }

    part def OneWayInspiratoryValve {
        attribute openPressureDrop : Pressure = 0.4;
        attribute reverseLeakageAt10cmH2O : LeakageRate = 0.2;
        attribute leafletStiffness : Real = 0.35;

        port upstreamPort : AirPort;
        port downstreamPort : NasalInterfacePort;

        action openDuringInspiration {
            in item ambient : AmbientAir;
            out item inspired : InspiredAir;
        }

        action closeDuringExpiration {
            in item expired : ExpiredAir;
            out item blockedReverseFlow : ExpiredAir;
        }

        state valveStates {
            state Closed;
            state Open;
            entry;
            then Closed;

            transition Closed_to_Open
                first Closed
                accept inspirationPressureDrop
                then Open;

            transition Open_to_Closed
                first Open
                accept expirationPressureRise
                then Closed;
        }
    }

    part def MicroOrificeArray {
        attribute orificeCount : Integer = 42;
        attribute singleOrificeDiameter : Length = 0.36 [mm];
        attribute totalFlowArea : Area = 4.2;
        attribute nominalResistance : Resistance = 1.0;
        attribute generatedPressureAt10LMin : Pressure = 10.0;

        port upstreamPort : NasalInterfacePort;
        port downstreamPort : AirPort;

        action generateBackPressure {
            in item expiredAir : ExpiredAir;
            out item resistedExpiredAir : ExpiredAir;
            out item effect : TherapyEffect;
        }
    }

    part def SoftNasalCushion {
        attribute materialShoreA : Real = 22.0;
        attribute insertionDepth : Length = 5.0 [mm];
        attribute contactForceNominal : Force = 0.35;
        attribute deadSpaceVolumeMl : Real = 1.8;

        port patientSide : NasalInterfacePort;
        port sealStatus : StatusPort;
    }

    part def SkinAdhesiveSeal {
        attribute peelStrength : Real = 1.2;
        attribute sealContactArea : Area = 420.0;
        attribute measuredLeakage : LeakageRate = 1.5;
        attribute biocompatible : Boolean = true;

        port leftSealInterface : StatusPort;
        port rightSealInterface : StatusPort;
        port statusPort : StatusPort;

        action maintainSeal {
            out item status : FitStatus;
        }
    }

    part def FlexibleBridge {
        attribute bridgeSpan : Length = 24.0 [mm];
        attribute flexuralCompliance : Real = 0.62;
        attribute alignmentTolerance : Length = 3.0 [mm];

        port leftMount : StatusPort;
        port rightMount : StatusPort;

        action alignNasalModules {
            out item fit : FitStatus;
        }
    }

    part def OverPressureRelief {
        attribute reliefCrackPressure : Pressure = 18.0;
        attribute reseatPressure : Pressure = 12.0;
        attribute reliefFlowAt20cmH2O : FlowRate = 18.0;

        port moduleInterface : AirPort;
        port ventPort : ReliefVentPort;

        action ventExcessPressure {
            in item pressurizedAir : ExpiredAir;
            out item ventedAir : ExpiredAir;
        }

        state reliefStates {
            state Seated;
            state Venting;

            entry;
            then Seated;

            transition Seated_to_Venting
                first Seated
                accept pressureAboveLimit
                then Venting;

            transition Venting_to_Seated
                first Venting
                accept pressureBelowReseat
                then Seated;
        }
    }

    part def ProtectiveGrid {
        attribute gridOpenArea : Area = 36.0;
        attribute particleExclusionSize : Length = 1.0 [mm];
        attribute occlusionResistanceIncrease : Real = 0.08;
    }

    part def HygienicPackage {
        attribute sterileBarrierIntact : Boolean;
        attribute shelfLifeDays : Integer = 730;
        attribute singleUseLabelPresent : Boolean = true;
        attribute lotTraceCode : String = "EPAP-LOT-2026-001";
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The nasal EPAP system shall provide passive expiratory positive airway pressure
         * by creating controlled resistance to nasal expiration while allowing low-resistance
         * nasal inspiration.
         */
        attribute requiredEPAPMinimum : Pressure = 4.0;
        attribute requiredEPAPMaximum : Pressure = 15.0;

        require constraint {
            requiredEPAPMinimum <= NasalEPAPSystem::targetEPAP and
            NasalEPAPSystem::targetEPAP <= requiredEPAPMaximum
        }
    }

    requirement def InspiratoryFlowRequirement {
        doc
        /*
         * The device shall allow inspiration with low pressure drop to avoid obstructing
         * normal nasal breathing.
         */
        attribute maximumInspiratoryPressureDrop : Pressure = 2.0;

        require constraint {
            NasalEPAPSystem::nominalInspiratoryDrop <= maximumInspiratoryPressureDrop
        }
    }

    requirement def ExpiratoryResistanceRequirement {
        doc
        /*
         * The expiratory flow path shall generate therapeutic back pressure during expiration.
         */
        attribute minimumPressureAtTherapyFlow : Pressure = 5.0;
        attribute therapyFlow : FlowRate = 10.0;

        require constraint {
            MicroOrificeArray::generatedPressureAt10LMin >= minimumPressureAtTherapyFlow
        }
    }

    requirement def PressureSafetyRequirement {
        doc
        /*
         * The device shall relieve pressure above the safe nasal pressure limit.
         */
        attribute pressureLimit : Pressure = 20.0;

        require constraint {
            OverPressureRelief::reliefCrackPressure < pressureLimit
        }
    }

    requirement def SealRequirement {
        doc
        /*
         * The nasal interface shall maintain a leak-controlled seal during intended sleep use.
         */
        attribute maximumAllowedLeakage : LeakageRate = 6.0;

        require constraint {
            SkinAdhesiveSeal::measuredLeakage <= maximumAllowedLeakage
        }
    }

    requirement def SingleUseHygieneRequirement {
        doc
        /*
         * The device shall be supplied in a hygienic package and identified for single-patient,
         * single-night use.
         */
        require constraint {
            HygienicPackage::sterileBarrierIntact == true and
            HygienicPackage::singleUseLabelPresent == true
        }
    }

    satisfy PrimaryFunctionRequirement by NasalEPAPSystem;
    satisfy InspiratoryFlowRequirement by OneWayInspiratoryValve;
    satisfy ExpiratoryResistanceRequirement by MicroOrificeArray;
    satisfy PressureSafetyRequirement by OverPressureRelief;
    satisfy SealRequirement by SkinAdhesiveSeal;
    satisfy SingleUseHygieneRequirement by HygienicPackage;

    /* Analysis views */

    view def HighLevelFunctionView {
        expose NasalEPAPSystem;
        expose NasalEPAPSystem::leftNasalModule;
        expose NasalEPAPSystem::rightNasalModule;
        expose NasalEPAPSystem::adhesiveSeal;
        expose NasalEPAPSystem::pressureRelief;
        expose PrimaryFunctionRequirement;
    }

    view def BreathingFlowView {
        expose AmbientAir;
        expose InspiredAir;
        expose ExpiredAir;
        expose NasalEPAPSystem::environmentPort;
        expose NasalEPAPSystem::patientPort;
        expose OneWayInspiratoryValve;
        expose MicroOrificeArray;
        expose OverPressureRelief;
    }

}
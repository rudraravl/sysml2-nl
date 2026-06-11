package TrachealTubeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "Pa";
    }

    attribute def FlowRate {
        :> scalarValues::Real;
        unit = "L/min";
    }

    attribute def Volume {
        :> scalarValues::Real;
        unit = "mL";
    }

    attribute def Length {
        :> scalarValues::Real;
        unit = "mm";
    }

    attribute def Diameter {
        :> scalarValues::Real;
        unit = "mm";
    }

    attribute def Force {
        :> scalarValues::Real;
        unit = "N";
    }

    attribute def Time {
        :> scalarValues::Real;
        unit = "s";
    }

    item def BreathingGas {
        attribute oxygenFraction : Real;
        attribute carbonDioxideFraction : Real;
        attribute humidity : Real;
        attribute temperature : Real;
        attribute flow : FlowRate;
        attribute pressure : Pressure;
    }

    item def ExhaledGas specializes BreathingGas {
        attribute carbonDioxideFraction : Real = 0.04;
    }

    item def AirwaySecretion {
        attribute viscosity : Real;
        attribute volume : Volume;
    }

    item def InflationGas {
        attribute volume : Volume;
        attribute pressure : Pressure;
    }

    item def MechanicalLoad {
        attribute axialForce : Force;
        attribute bendingMoment : Real;
    }

    port def GasPort {
        in item gasIn : BreathingGas;
        out item gasOut : BreathingGas;
    }

    port def BidirectionalAirwayPort {
        in item inspiredGas : BreathingGas;
        out item expiredGas : ExhaledGas;
        inout item secretion : AirwaySecretion;
    }

    port def InflationPort {
        in item inflationGas : InflationGas;
        out item pressureSignal : InflationGas;
    }

    port def SuctionPort {
        out item removedSecretion : AirwaySecretion;
        in item suctionFlow : BreathingGas;
    }

    port def MechanicalInterfacePort {
        inout item load : MechanicalLoad;
    }

    part def TrachealTubeSystem {

        attribute primaryFunction : String =
            "Maintain a patent artificial airway through the trachea to enable ventilation, oxygen delivery, carbon dioxide removal, airway protection, and secretion management.";

        attribute nominalAdultInternalDiameter : Diameter = 7.5;
        attribute nominalTubeLength : Length = 320.0;
        attribute maximumRecommendedCuffPressure : Pressure = 3000.0;
        attribute minimumSealPressure : Pressure = 2000.0;
        attribute maximumAirwayResistance : Pressure = 500.0;

        port ventilatorInterface : GasPort;
        port patientAirwayInterface : BidirectionalAirwayPort;
        port cuffInflationInterface : InflationPort;
        port suctionInterface : SuctionPort;
        port fixationInterface : MechanicalInterfacePort;

        part connectorHub : ConnectorHub;
        part tubeShaft : CurvedTubeShaft;
        part distalTip : BeveledDistalTip;
        part inflatableCuff : LowPressureCuff;
        part pilotBalloonAssembly : PilotBalloonAssembly;
        part cuffInflationLine : InflationLine;
        part radiopaqueMarker : RadiopaqueMarker;
        part depthMarkings : DepthMarkingSet;
        part murphyEye : SideVentOpening;
        part suctionLumen : SubglotticSuctionLumen;
        part fixationFlange : FixationFlange;

        connect ventilatorInterface to connectorHub.ventilatorPort;
        connect connectorHub.tubePort to tubeShaft.proximalGasPort;
        connect tubeShaft.distalGasPort to distalTip.mainAirwayPort;
        connect distalTip.patientPort to patientAirwayInterface;

        connect cuffInflationInterface to pilotBalloonAssembly.externalInflationPort;
        connect pilotBalloonAssembly.linePort to cuffInflationLine.proximalInflationPort;
        connect cuffInflationLine.distalInflationPort to inflatableCuff.inflationPort;

        connect suctionInterface to suctionLumen.externalSuctionPort;
        connect suctionLumen.distalSuctionPort to patientAirwayInterface;

        connect fixationInterface to fixationFlange.externalFixationPort;
        connect fixationFlange.tubeGripPort to tubeShaft.mechanicalPort;

        connect murphyEye.sideAirwayPort to patientAirwayInterface;
        connect murphyEye.tubeSidePort to tubeShaft.distalGasPort;

        action maintainArtificialAirway {
            in item deliveredGas : BreathingGas;
            out item exhaledGas : ExhaledGas;
            out item removedSecretion : AirwaySecretion;

            first start;
            then placeTube;
            then verifyPosition;
            then inflateCuff;
            then provideVentilation;
            then manageSecretions;
            then monitorSeal;
            then end;

            action placeTube {
                out item airwayPath : BreathingGas;
            }

            action verifyPosition {
                in item airwayPath : BreathingGas;
                out success : Boolean;
            }

            action inflateCuff {
                in item gas : InflationGas;
                out item sealedCuffGas : InflationGas;
            }

            action provideVentilation {
                in item inspiredGas : BreathingGas;
                out item expiredGas : ExhaledGas;
            }

            action manageSecretions {
                inout item secretion : AirwaySecretion;
                out item aspiratedSecretion : AirwaySecretion;
            }

            action monitorSeal {
                in item cuffGas : InflationGas;
                out cuffPressureAcceptable : Boolean;
            }
        }

        state airwaySupportState {
            entry action initializeTubeReadiness;

            state Uninserted;
            state InsertedUnsealed;
            state SealedAndVentilating;
            state SecretionManagement;
            state AlarmCondition;
            state Removed;

            transition first Uninserted;

            transition Uninserted_to_InsertedUnsealed
                first Uninserted
                then InsertedUnsealed
                accept insertionCompleted;

            transition InsertedUnsealed_to_SealedAndVentilating
                first InsertedUnsealed
                then SealedAndVentilating
                accept cuffPressureReached
                if inflatableCuff.cuffPressure >= minimumSealPressure and
                   inflatableCuff.cuffPressure <= maximumRecommendedCuffPressure;

            transition SealedAndVentilating_to_SecretionManagement
                first SealedAndVentilating
                then SecretionManagement
                accept secretionDetected;

            transition SecretionManagement_to_SealedAndVentilating
                first SecretionManagement
                then SealedAndVentilating
                accept suctionCompleted;

            transition SealedAndVentilating_to_AlarmCondition
                first SealedAndVentilating
                then AlarmCondition
                accept unsafePressureDetected
                if inflatableCuff.cuffPressure > maximumRecommendedCuffPressure;

            transition AlarmCondition_to_SealedAndVentilating
                first AlarmCondition
                then SealedAndVentilating
                accept pressureCorrected
                if inflatableCuff.cuffPressure <= maximumRecommendedCuffPressure;

            transition SealedAndVentilating_to_Removed
                first SealedAndVentilating
                then Removed
                accept extubationCompleted;
        }
    }

    part def ConnectorHub {
        attribute standardConnectorDiameter : Diameter = 15.0;
        attribute leakRateAtNominalPressure : FlowRate = 0.05;

        port ventilatorPort : GasPort;
        port tubePort : GasPort;

        requirement connectorCompatibility {
            doc /* The connector shall provide a standard ventilator interface for breathing circuit attachment. */
            require constraint { standardConnectorDiameter == 15.0 }
        }
    }

    part def CurvedTubeShaft {
        attribute internalDiameter : Diameter = 7.5;
        attribute externalDiameter : Diameter = 10.2;
        attribute length : Length = 320.0;
        attribute curvatureRadius : Length = 140.0;
        attribute airwayResistanceAtThirtyLpm : Pressure = 350.0;
        attribute materialFlexibility : Real = 0.72;

        port proximalGasPort : GasPort;
        port distalGasPort : GasPort;
        port mechanicalPort : MechanicalInterfacePort;

        requirement flowPatency {
            doc /* The tube shaft shall maintain a continuous lumen for bidirectional flow of inspired and expired gas. */
            require constraint { internalDiameter >= 6.0 }
            require constraint { airwayResistanceAtThirtyLpm <= 500.0 }
        }
    }

    part def BeveledDistalTip {
        attribute bevelAngle : Real = 38.0;
        attribute tipSoftness : Real = 0.85;
        attribute distalOpeningArea : Real = 44.2;

        port mainAirwayPort : GasPort;
        port patientPort : BidirectionalAirwayPort;

        requirement atraumaticEntry {
            doc /* The distal tip shall support guided tracheal insertion while reducing contact trauma. */
            require constraint { bevelAngle >= 30.0 and bevelAngle <= 45.0 }
            require constraint { tipSoftness >= 0.75 }
        }
    }

    part def LowPressureCuff {
        attribute cuffPressure : Pressure = 2500.0;
        attribute inflationVolume : Volume = 8.0;
        attribute sealContactLength : Length = 28.0;
        attribute cuffOuterDiameterInflated : Diameter = 24.0;

        port inflationPort : InflationPort;
        port trachealSealSurface : MechanicalInterfacePort;

        requirement trachealSeal {
            doc /* The cuff shall create a tracheal seal sufficient for positive-pressure ventilation while limiting mucosal pressure. */
            require constraint { cuffPressure >= 2000.0 }
            require constraint { cuffPressure <= 3000.0 }
        }
    }

    part def PilotBalloonAssembly {
        attribute indicatedPressure : Pressure = 2500.0;
        attribute checkValveLeakRate : FlowRate = 0.01;

        port externalInflationPort : InflationPort;
        port linePort : InflationPort;

        action indicateCuffPressure {
            in item cuffGas : InflationGas;
            out indicatedPressure : Pressure;
        }

        requirement pressureIndication {
            doc /* The pilot balloon assembly shall provide tactile and pneumatic indication of cuff inflation status. */
            require constraint { checkValveLeakRate <= 0.02 }
        }
    }

    part def InflationLine {
        attribute internalVolume : Volume = 1.2;
        attribute kinkResistance : Real = 0.9;

        port proximalInflationPort : InflationPort;
        port distalInflationPort : InflationPort;

        requirement inflationContinuity {
            doc /* The inflation line shall transmit inflation gas between the pilot balloon assembly and cuff without clinically significant leakage. */
            require constraint { kinkResistance >= 0.8 }
        }
    }

    part def RadiopaqueMarker {
        attribute markerLength : Length = 280.0;
        attribute radiopacityIndex : Real = 0.95;

        requirement imagingVisibility {
            doc /* The radiopaque marker shall enable tube position confirmation by radiographic imaging. */
            require constraint { radiopacityIndex >= 0.9 }
        }
    }

    part def DepthMarkingSet {
        attribute firstVisibleMark : Length = 160.0;
        attribute lastVisibleMark : Length = 280.0;
        attribute markInterval : Length = 10.0;
        attribute contrastRatio : Real = 0.88;

        requirement insertionDepthReference {
            doc /* Depth markings shall support visual estimation of insertion depth at the teeth or lips. */
            require constraint { markInterval == 10.0 }
            require constraint { contrastRatio >= 0.8 }
        }
    }

    part def SideVentOpening {
        attribute openingArea : Real = 18.0;
        attribute distanceFromTip : Length = 8.0;

        port sideAirwayPort : BidirectionalAirwayPort;
        port tubeSidePort : GasPort;

        requirement alternateGasPath {
            doc /* The side vent shall provide an alternate gas pathway if the distal tip opening is partially obstructed. */
            require constraint { openingArea >= 12.0 }
            require constraint { distanceFromTip <= 12.0 }
        }
    }

    part def SubglotticSuctionLumen {
        attribute lumenDiameter : Diameter = 2.0;
        attribute maximumSuctionFlow : FlowRate = 5.0;
        attribute secretionRemovalEfficiency : Real = 0.8;

        port externalSuctionPort : SuctionPort;
        port distalSuctionPort : BidirectionalAirwayPort;

        action removeSecretions {
            in item pooledSecretion : AirwaySecretion;
            out item removedSecretion : AirwaySecretion;
        }

        requirement secretionManagementCapability {
            doc /* The suction lumen shall enable removal of secretions accumulated above the cuff. */
            require constraint { lumenDiameter >= 1.5 }
            require constraint { secretionRemovalEfficiency >= 0.7 }
        }
    }

    part def FixationFlange {
        attribute strapForceLimit : Force = 12.0;
        attribute rotationalStability : Real = 0.86;

        port externalFixationPort : MechanicalInterfacePort;
        port tubeGripPort : MechanicalInterfacePort;

        requirement securement {
            doc /* The fixation interface shall permit external securement of the tube while limiting axial displacement. */
            require constraint { strapForceLimit >= 8.0 }
            require constraint { rotationalStability >= 0.8 }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The tracheal tube system shall provide a controlled artificial airway between an external breathing circuit and the patient's trachea for ventilation and gas exchange support. */
        subject tubeSystem : TrachealTubeSystem;
        require constraint {
            tubeSystem.nominalAdultInternalDiameter >= 6.0 and
            tubeSystem.maximumAirwayResistance <= 500.0
        }
    }

    requirement def AirwayProtectionRequirement {
        doc /* The system shall reduce aspiration risk during ventilation by sealing the tracheal wall with an inflatable cuff. */
        subject cuff : LowPressureCuff;
        require constraint {
            cuff.cuffPressure >= 2000.0 and
            cuff.cuffPressure <= 3000.0
        }
    }

    requirement def VentilationContinuityRequirement {
        doc /* The system shall support continuous bidirectional gas flow for inspiration and expiration while inserted. */
        subject tube : CurvedTubeShaft;
        require constraint {
            tube.internalDiameter >= 6.0 and
            tube.airwayResistanceAtThirtyLpm <= 500.0
        }
    }

    requirement def PositionVerificationRequirement {
        doc /* The system shall include visual and radiographic features that support verification of insertion depth and position. */
        subject system : TrachealTubeSystem;
        require constraint {
            system.radiopaqueMarker.radiopacityIndex >= 0.9 and
            system.depthMarkings.contrastRatio >= 0.8
        }
    }

    requirement def SecretionRemovalRequirement {
        doc /* The system shall provide a means to evacuate airway secretions without interrupting the primary ventilation path. */
        subject suction : SubglotticSuctionLumen;
        require constraint {
            suction.lumenDiameter >= 1.5 and
            suction.secretionRemovalEfficiency >= 0.7
        }
    }

    part adultCuffedTrachealTube : TrachealTubeSystem;

    satisfy PrimaryFunctionRequirement by adultCuffedTrachealTube;
    satisfy AirwayProtectionRequirement by adultCuffedTrachealTube.inflatableCuff;
    satisfy VentilationContinuityRequirement by adultCuffedTrachealTube.tubeShaft;
    satisfy PositionVerificationRequirement by adultCuffedTrachealTube;
    satisfy SecretionRemovalRequirement by adultCuffedTrachealTube.suctionLumen;
}
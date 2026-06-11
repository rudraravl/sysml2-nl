package AdvancedAirwaySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalarQuantity;
        unit = "cmH2O";
    }

    attribute def FlowRate {
        :> scalarQuantity;
        unit = "L/min";
    }

    attribute def Volume {
        :> scalarQuantity;
        unit = "mL";
    }

    attribute def Length {
        :> scalarQuantity;
        unit = "mm";
    }

    attribute def Time {
        :> scalarQuantity;
        unit = "s";
    }

    attribute def Fraction {
        :> scalarQuantity;
        unit = "1";
    }

    attribute def Concentration {
        :> scalarQuantity;
        unit = "mmHg";
    }

    item def OxygenRichGas {
        attribute oxygenFraction : Fraction;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    item def ExhaledGas {
        attribute carbonDioxidePartialPressure : Concentration;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    item def AirwaySecretion {
        attribute volume : Volume;
        attribute viscosityLevel : Integer;
    }

    item def CuffInflationGas {
        attribute volume : Volume;
        attribute pressure : Pressure;
    }

    item def PatientRespiratorySignal {
        attribute airwayPressure : Pressure;
        attribute tidalVolume : Volume;
        attribute endTidalCO2 : Concentration;
        attribute respiratoryRate : Integer;
    }

    port def GasInletPort {
        in item suppliedGas : OxygenRichGas;
    }

    port def GasOutletPort {
        out item deliveredGas : OxygenRichGas;
    }

    port def ExhalationPort {
        in item exhaledGas : ExhaledGas;
    }

    port def PatientAirwayPort {
        out item inspiredGas : OxygenRichGas;
        in item expiredGas : ExhaledGas;
        in item secretions : AirwaySecretion;
    }

    port def CuffPort {
        in item inflationGas : CuffInflationGas;
        out attribute measuredCuffPressure : Pressure;
    }

    port def MonitoringPort {
        out item respiratorySignal : PatientRespiratorySignal;
    }

    part def AdvancedAirway {
        attribute internalDiameter : Length = 7.5 [mm];
        attribute externalDiameter : Length = 10.2 [mm];
        attribute insertionDepth : Length = 220 [mm];
        attribute maximumDeadSpace : Volume = 35 [mL];
        attribute allowableCuffPressureMin : Pressure = 20 [cmH2O];
        attribute allowableCuffPressureMax : Pressure = 30 [cmH2O];

        port proximalGasPort : GasInletPort;
        port distalAirwayPort : PatientAirwayPort;
        port cuffControlPort : CuffPort;
        port monitorPort : MonitoringPort;

        part airwayTube : AirwayTube;
        part inflatableCuff : InflatableCuff;
        part connector : StandardConnector;
        part pilotBalloon : PilotBalloon;
        part suctionLumen : SubglotticSuctionLumen;
        part depthMarkerSet : DepthMarkerSet;

        connect proximalGasPort to connector.ventilatorSidePort;
        connect connector.patientSidePort to airwayTube.proximalPort;
        connect airwayTube.distalPort to distalAirwayPort;
        connect cuffControlPort to pilotBalloon.externalCuffPort;
        connect pilotBalloon.cuffSupplyPort to inflatableCuff.cuffGasPort;
        connect monitorPort to airwayTube.monitoringTap;
        connect suctionLumen.distalSecretionPort to distalAirwayPort;
    }

    part def AirwayTube {
        attribute length : Length = 300 [mm];
        attribute internalDiameter : Length = 7.5 [mm];
        attribute kinkResistanceLimit : Pressure = 60 [cmH2O];

        port proximalPort : GasInletPort;
        port distalPort : PatientAirwayPort;
        port monitoringTap : MonitoringPort;
    }

    part def InflatableCuff {
        attribute nominalInflationVolume : Volume = 8 [mL];
        attribute sealPressureTarget : Pressure = 25 [cmH2O];
        attribute maximumSafePressure : Pressure = 30 [cmH2O];

        port cuffGasPort : CuffPort;
    }

    part def StandardConnector {
        attribute connectorDiameter : Length = 15 [mm];

        port ventilatorSidePort : GasInletPort;
        port patientSidePort : GasOutletPort;
    }

    part def PilotBalloon {
        attribute indicatedPressure : Pressure;

        port externalCuffPort : CuffPort;
        port cuffSupplyPort : CuffPort;
    }

    part def SubglotticSuctionLumen {
        attribute suctionPressureLimit : Pressure = -120 [cmH2O];
        attribute secretionRemovalRate : FlowRate = 0.2 [L/min];

        port distalSecretionPort : PatientAirwayPort;
    }

    part def DepthMarkerSet {
        attribute oralMarkerStart : Length = 180 [mm];
        attribute oralMarkerEnd : Length = 240 [mm];
        attribute markerSpacing : Length = 10 [mm];
    }

    part def VentilationSource {
        attribute setTidalVolume : Volume = 500 [mL];
        attribute peakInspiratoryPressureLimit : Pressure = 35 [cmH2O];
        attribute oxygenFractionSetting : Fraction = 0.50;
        attribute inspiratoryFlowSetting : FlowRate = 40 [L/min];

        port gasDeliveryPort : GasOutletPort;
        port exhaledGasPort : ExhalationPort;
    }

    part def PatientAirway {
        attribute trachealDiameter : Length = 18 [mm];
        attribute requiredTidalVolume : Volume = 500 [mL];
        attribute minimumOxygenFraction : Fraction = 0.21;
        attribute targetEndTidalCO2Low : Concentration = 35 [mmHg];
        attribute targetEndTidalCO2High : Concentration = 45 [mmHg];

        port airwayInterfacePort : PatientAirwayPort;
    }

    part def AirwayPressureMonitor {
        attribute highPressureAlarmThreshold : Pressure = 35 [cmH2O];
        attribute lowPressureAlarmThreshold : Pressure = 5 [cmH2O];
        attribute samplingPeriod : Time = 0.1 [s];

        port sensePort : MonitoringPort;
    }

    part def AdvancedAirwaySupportSystem {
        attribute primaryFunction : String = "Maintain a protected artificial airway that permits controlled oxygenation, ventilation, secretion management, and airway pressure monitoring for a patient unable to maintain adequate spontaneous airway patency.";

        part airway : AdvancedAirway;
        part ventilator : VentilationSource;
        part patient : PatientAirway;
        part pressureMonitor : AirwayPressureMonitor;

        connect ventilator.gasDeliveryPort to airway.proximalGasPort;
        connect airway.distalAirwayPort to patient.airwayInterfacePort;
        connect airway.monitorPort to pressureMonitor.sensePort;
        connect patient.airwayInterfacePort to ventilator.exhaledGasPort;

        perform action establishAirway;
        perform action deliverBreath;
        perform action monitorVentilation;
        exhibit state airwayOperationalState;
    }

    action def EstablishArtificialAirway {
        in attribute insertionDepthCommand : Length;
        out attribute airwaySecured : Boolean;
        out attribute cuffPressure : Pressure;

        first start;
        then insertTube;
        then confirmPlacement;
        then inflateCuff;
        then secureTube;
        then done;

        action insertTube {
            out attribute positionedAtDepth : Length = insertionDepthCommand;
        }

        action confirmPlacement {
            out attribute bilateralChestRiseObserved : Boolean = true;
            out attribute endTidalCO2Detected : Boolean = true;
        }

        action inflateCuff {
            out attribute achievedCuffPressure : Pressure = 25 [cmH2O];
        }

        action secureTube {
            out attribute fixationApplied : Boolean = true;
        }
    }

    action def DeliverControlledVentilation {
        in item suppliedGas : OxygenRichGas;
        out item inspiredGas : OxygenRichGas;
        out item expiredGas : ExhaledGas;
        out attribute deliveredTidalVolume : Volume;
        out attribute peakAirwayPressure : Pressure;

        first inspiration;
        then pause;
        then expiration;
        then breathComplete;

        action inspiration {
            out item inspiredFlow : OxygenRichGas;
            out attribute inspiredVolume : Volume = 500 [mL];
        }

        action pause {
            out attribute plateauPressure : Pressure = 22 [cmH2O];
        }

        action expiration {
            out item expiredFlow : ExhaledGas;
            out attribute measuredEndTidalCO2 : Concentration = 40 [mmHg];
        }
    }

    action def MonitorAirwayStatus {
        in item respiratorySignal : PatientRespiratorySignal;
        out attribute pressureAlarmActive : Boolean;
        out attribute ventilationAdequate : Boolean;
        out attribute airwayPatencyConfirmed : Boolean;

        first samplePressure;
        then sampleCarbonDioxide;
        then evaluatePatency;
        then publishStatus;

        action samplePressure {
            out attribute measuredPressure : Pressure;
        }

        action sampleCarbonDioxide {
            out attribute measuredEtCO2 : Concentration;
        }

        action evaluatePatency {
            out attribute obstructionDetected : Boolean = false;
            out attribute leakDetected : Boolean = false;
        }

        action publishStatus {
            out attribute statusAvailable : Boolean = true;
        }
    }

    state def AirwayOperationalState {
        entry action initializeMonitoring;

        state Unplaced;
        state Placing;
        state PlacementConfirmed;
        state CuffSealed;
        state Ventilating;
        state Alarm;
        state Removed;

        transition first Unplaced;
        transition Unplaced_to_Placing
            first Unplaced
            then Placing
            accept InsertCommand;

        transition Placing_to_PlacementConfirmed
            first Placing
            then PlacementConfirmed
            accept PlacementConfirmedSignal;

        transition PlacementConfirmed_to_CuffSealed
            first PlacementConfirmed
            then CuffSealed
            accept CuffPressureWithinRange;

        transition CuffSealed_to_Ventilating
            first CuffSealed
            then Ventilating
            accept VentilationStarted;

        transition Ventilating_to_Alarm
            first Ventilating
            then Alarm
            accept HighPressureDetected;

        transition Alarm_to_Ventilating
            first Alarm
            then Ventilating
            accept AlarmResolved;

        transition Ventilating_to_Removed
            first Ventilating
            then Removed
            accept ExtubationCommand;
    }

    requirement def MaintainArtificialAirwayRequirement {
        doc /* The advanced airway shall maintain a patent artificial airway between the ventilation source and the patient's trachea during controlled ventilation. */
        subject system : AdvancedAirwaySupportSystem;

        require constraint {
            system.airway.airwayTube.internalDiameter >= 6.0 [mm]
        }
    }

    requirement def DeliverTidalVolumeRequirement {
        doc /* The system shall deliver a clinician-set tidal volume to the patient through the advanced airway while limiting peak inspiratory pressure. */
        subject system : AdvancedAirwaySupportSystem;

        require constraint {
            system.ventilator.setTidalVolume >= 300 [mL] and
            system.ventilator.setTidalVolume <= 800 [mL] and
            system.ventilator.peakInspiratoryPressureLimit <= 35 [cmH2O]
        }
    }

    requirement def CuffSealRequirement {
        doc /* The cuff shall provide a tracheal seal sufficient to reduce aspiration and ventilation leak while maintaining mucosal pressure within the safe range. */
        subject airway : AdvancedAirway;

        require constraint {
            airway.inflatableCuff.sealPressureTarget >= airway.allowableCuffPressureMin and
            airway.inflatableCuff.sealPressureTarget <= airway.allowableCuffPressureMax
        }
    }

    requirement def OxygenationRequirement {
        doc /* The system shall support delivery of oxygen-enriched gas to the patient airway. */
        subject system : AdvancedAirwaySupportSystem;

        require constraint {
            system.ventilator.oxygenFractionSetting >= system.patient.minimumOxygenFraction and
            system.ventilator.oxygenFractionSetting <= 1.0
        }
    }

    requirement def CarbonDioxideMonitoringRequirement {
        doc /* The system shall provide respiratory monitoring sufficient to confirm ventilation by measuring end-tidal carbon dioxide. */
        subject monitor : AirwayPressureMonitor;

        require constraint {
            monitor.samplingPeriod <= 1.0 [s]
        }
    }

    requirement def SecretionManagementRequirement {
        doc /* The advanced airway shall include a secretion management pathway to remove subglottic secretions without interrupting ventilation. */
        subject airway : AdvancedAirway;

        require constraint {
            airway.suctionLumen.secretionRemovalRate > 0.0 [L/min]
        }
    }

    requirement def ConnectorCompatibilityRequirement {
        doc /* The proximal connector shall be compatible with standard ventilation equipment. */
        subject airway : AdvancedAirway;

        require constraint {
            airway.connector.connectorDiameter == 15 [mm]
        }
    }

    requirement def PlacementDepthVisibilityRequirement {
        doc /* The airway shall provide visible depth markings to support placement verification and ongoing migration detection. */
        subject airway : AdvancedAirway;

        require constraint {
            airway.depthMarkerSet.markerSpacing <= 10 [mm]
        }
    }

    satisfy MaintainArtificialAirwayRequirement by AdvancedAirwaySupportSystem;
    satisfy DeliverTidalVolumeRequirement by AdvancedAirwaySupportSystem;
    satisfy CuffSealRequirement by AdvancedAirway;
    satisfy OxygenationRequirement by AdvancedAirwaySupportSystem;
    satisfy CarbonDioxideMonitoringRequirement by AirwayPressureMonitor;
    satisfy SecretionManagementRequirement by AdvancedAirway;
    satisfy ConnectorCompatibilityRequirement by AdvancedAirway;
    satisfy PlacementDepthVisibilityRequirement by AdvancedAirway;

    part advancedAirwaySystem : AdvancedAirwaySupportSystem {
        :>> airway {
            :>> internalDiameter = 7.5 [mm];
            :>> insertionDepth = 220 [mm];
        }

        :>> ventilator {
            :>> setTidalVolume = 500 [mL];
            :>> oxygenFractionSetting = 0.50;
            :>> peakInspiratoryPressureLimit = 35 [cmH2O];
        }

        :>> patient {
            :>> requiredTidalVolume = 500 [mL];
            :>> targetEndTidalCO2Low = 35 [mmHg];
            :>> targetEndTidalCO2High = 45 [mmHg];
        }
    }

    action establishAirway : EstablishArtificialAirway {
        insertionDepthCommand = 220 [mm];
    }

    action deliverBreath : DeliverControlledVentilation;

    action monitorVentilation : MonitorAirwayStatus;
}
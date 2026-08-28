package TrachealIntubationSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def PressureValue :> Real {
        unit 'mmHg';
    }

    value def VolumeValue :> Real {
        unit 'mL';
    }

    value def FlowRateValue :> Real {
        unit 'L/min';
    }

    value def FrequencyValue :> Real {
        unit 'breaths/min';
    }

    value def PercentageValue :> Real {
        unit '%';
    }

    value def TemperatureValue :> Real {
        unit 'degC';
    }

    value def HeartRateValue :> Real {
        unit 'beats/min';
    }

    value def LengthValue :> Real {
        unit 'mm';
    }

    value def DiameterValue :> Real {
        unit 'mm';
    }

    // ===== Item Types =====

    item def AirOxygenMixture {
        attribute oxygenFraction : PercentageValue;
        attribute totalVolume : VolumeValue;
        attribute flowRate : FlowRateValue;
    }

    item def ExhaledGas {
        attribute etCO2 : PercentageValue;
        attribute volume : VolumeValue;
    }

    item def Secretions;

    item def CuffInflationAir {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }

    // ===== Port Definitions =====

    port def AirwayPort {
        in item exhaled : ExhaledGas;
        out item inspired : AirOxygenMixture;
    }

    port def VentilatorPort {
        out item delivered : AirOxygenMixture;
        in item returned : ExhaledGas;
    }

    port def TubeConnectorPort {
        in item ventilation : AirOxygenMixture;
        out item exhalation : ExhaledGas;
    }

    port def CuffPort {
        in item inflation : CuffInflationAir;
    }

    port def SuctionPort {
        out item removed : Secretions;
    }

    port def MonitoringPort {
        out attribute spo2 : PercentageValue;
        out attribute etCO2 : PercentageValue;
        out attribute heartRate : HeartRateValue;
        out attribute airwayPressure : PressureValue;
    }

    port def AlarmPort {
        out attribute alarmActive : Boolean;
        out attribute alarmMessage : String;
    }

    // ===== Requirements =====

    requirement def SecureAirwayEstablished {
        doc /* The system shall establish a secure airway for the patient. */
        subject patient : Patient;
        requirement tubePlacementConfirmed :> SecureAirwayEstablished {
            doc /* Tube placement in the trachea shall be confirmed via EtCO2 detection. */
        }
        requirement cuffSealAchieved :> SecureAirwayEstablished {
            doc /* The cuff shall be inflated to a pressure between 20 and 30 mmHg. */
            attribute minCuffPressure : PressureValue = 20;
            attribute maxCuffPressure : PressureValue = 30;
        }
    }

    requirement def VentilationDelivered {
        doc /* The ventilator shall deliver a specified volume of air-oxygen mixture at a set respiratory rate. */
        subject ventilator : MechanicalVentilator;
        attribute tidalVolume : VolumeValue = 500;
        attribute respiratoryRate : FrequencyValue = 12;
        attribute oxygenFraction : PercentageValue = 60;
    }

    requirement def PatientMonitored {
        doc /* The patient monitor shall continuously track SpO2, EtCO2, and heart rate. */
        subject monitor : PatientMonitor;
        attribute minSpO2 : PercentageValue = 92;
        attribute maxEtCO2 : PercentageValue = 6;
        attribute minHeartRate : HeartRateValue = 50;
        attribute maxHeartRate : HeartRateValue = 120;
    }

    requirement def AirwayPressureAlarm {
        doc /* The ventilator shall sound an alarm if airway pressure exceeds a threshold. */
        subject ventilator : MechanicalVentilator;
        attribute maxAirwayPressure : PressureValue = 40;
    }

    // ===== Parts: Devices =====

    part def Patient {
        attribute ageYears : Integer;
        attribute weightKg : Real;
        port airway : AirwayPort;
        port trachealAccess : AirwayPort;
    }

    part def EndotrachealTube {
        attribute tubeLength : LengthValue = 300;
        attribute innerDiameter : DiameterValue = 8.0;
        attribute outerDiameter : DiameterValue = 11.0;
        part cuff : InflatableCuff;
        part tubeBody : TubeBody;
        port proximalConnector : TubeConnectorPort;
        port cuffInflationPort : CuffPort;
        port distalEnd : AirwayPort;

        part def InflatableCuff {
            attribute currentPressure : PressureValue;
            attribute maxVolume : VolumeValue = 10;
            attribute isInflated : Boolean;
            port inflationPort : CuffPort;
        }

        part def TubeBody {
            attribute material : String = "PVC";
            attribute radiopaque : Boolean = true;
        }
    }

    part def Laryngoscope {
        attribute bladeSize : Integer;
        attribute bladeType : String = "Macintosh";
        part handle : Handle {
            attribute batteryLevel : PercentageValue;
        }
        part blade : Blade {
            attribute length : LengthValue;
        }
        part lightSource : LightSource {
            attribute isOn : Boolean;
            attribute luminousIntensity : Real;
        }

        part def Handle;
        part def Blade;
        part def LightSource;
    }

    part def MechanicalVentilator {
        attribute tidalVolumeSetting : VolumeValue = 500;
        attribute respiratoryRateSetting : FrequencyValue = 12;
        attribute oxygenFractionSetting : PercentageValue = 60;
        attribute currentAirwayPressure : PressureValue;
        attribute maxPressureThreshold : PressureValue = 40;
        attribute isVentilating : Boolean;
        port patientCircuit : VentilatorPort;
        port alarmOutput : AlarmPort;
        port monitoringOutput : MonitoringPort;

        state def VentilatorStates {
            entry; then Off;
            state Off;
            state Standby;
            state Ventilating;
            state AlarmActive;
            transition off_to_standby
                first Off
                then Standby
                if powerOn;
            transition standby_to_ventilating
                first Standby
                then Ventilating
                if startVentilation;
            transition ventilating_to_alarm
                first Ventilating
                then AlarmActive
                if currentAirwayPressure > maxPressureThreshold;
            transition alarm_to_ventilating
                first AlarmActive
                then Ventilating
                if alarmAcknowledged && currentAirwayPressure <= maxPressureThreshold;
            transition ventilating_to_standby
                first Ventilating
                then Standby
                if stopVentilation;
        }
    }

    part def PatientMonitor {
        attribute spo2Reading : PercentageValue;
        attribute etCO2Reading : PercentageValue;
        attribute heartRateReading : HeartRateValue;
        attribute airwayPressureReading : PressureValue;
        attribute isMonitoring : Boolean;
        port sensorInput : MonitoringPort;
        port alarmOutput : AlarmPort;

        state def MonitorStates {
            entry; then Inactive;
            state Inactive;
            state Active;
            state Alert;
            transition inactive_to_active
                first Inactive
                then Active
                if monitoringStarted;
            transition active_to_alert
                first Active
                then Alert
                if spo2Reading < 92 || etCO2Reading > 6 || heartRateReading < 50 || heartRateReading > 120;
            transition alert_to_active
                first Alert
                then Active
                if vitalSignsNormalized;
        }
    }

    part def SuctionDevice {
        attribute suctionPressure : PressureValue;
        attribute isOperating : Boolean;
        attribute collectionContainerVolume : VolumeValue;
        port suctionOutput : SuctionPort;
    }

    part def CuffPressureManometer {
        attribute measuredPressure : PressureValue;
        attribute targetPressure : PressureValue = 25;
        port cuffConnection : CuffPort;
    }

    // ===== Clinical Process Behavior =====

    action def IntubationProcedure {
        in patient : Patient;
        in tube : EndotrachealTube;
        in laryngoscope : Laryngoscope;
        in ventilator : MechanicalVentilator;
        in monitor : PatientMonitor;
        in suction : SuctionDevice;
        in manometer : CuffPressureManometer;

        action prepareAndPositionPatient {
            doc /* Position patient in sniffing position, preoxygenate. */
            out patientReady : Boolean;
        }

        action clearAirwayWithSuction {
            doc /* Use suction device to remove secretions. */
            in suctionDevice : SuctionDevice = suction;
            out airwayCleared : Boolean;
        }

        action performLaryngoscopy {
            doc /* Insert laryngoscope blade, activate light, visualize vocal cords. */
            in instrument : Laryngoscope = laryngoscope;
            out vocalCordsVisualized : Boolean;
        }

        action insertEndotrachealTube {
            doc /* Guide tube through vocal cords into trachea. */
            in etTube : EndotrachealTube = tube;
            in visualizationAchieved : Boolean = performLaryngoscopy.vocalCordsVisualized;
            out tubeInserted : Boolean;
        }

        action confirmTubePlacement {
            doc /* Confirm placement via EtCO2 detection and bilateral chest rise. */
            in monitorDevice : PatientMonitor = monitor;
            in tubeInPlace : Boolean = insertEndotrachealTube.tubeInserted;
            out placementConfirmed : Boolean;
        }

        action inflateCuff {
            doc /* Inflate cuff to correct pressure using manometer. */
            in etTube : EndotrachealTube = tube;
            in pressureGauge : CuffPressureManometer = manometer;
            out cuffSealed : Boolean;
        }

        action secureTube {
            doc /* Secure tube at appropriate depth. */
            out tubeSecured : Boolean;
        }

        action initiateVentilation {
            doc /* Connect ventilator and begin mechanical ventilation. */
            in vent : MechanicalVentilator = ventilator;
            in etTube : EndotrachealTube = tube;
            out ventilationStarted : Boolean;
        }

        action continuousMonitoring {
            doc /* Continuously monitor patient vitals and ventilator parameters. */
            in monitorDevice : PatientMonitor = monitor;
            in vent : MechanicalVentilator = ventilator;
            out monitoringActive : Boolean;
        }

        // Control flow
        first prepareAndPositionPatient;
        then clearAirwayWithSuction;
        then performLaryngoscopy;
        then insertEndotrachealTube;
        then confirmTubePlacement;
        then inflateCuff;
        then secureTube;
        then initiateVentilation;
        then continuousMonitoring;
    }

    // ===== System Assembly =====

    part def IntubationSystem {
        part patient : Patient {
            attribute ageYears = 45;
            attribute weightKg = 70.0;
        }

        part endotrachealTube : EndotrachealTube {
            attribute tubeLength = 300;
            attribute innerDiameter = 8.0;
        }

        part laryngoscope : Laryngoscope {
            attribute bladeSize = 3;
            attribute bladeType = "Macintosh";
        }

        part ventilator : MechanicalVentilator {
            attribute tidalVolumeSetting = 500;
            attribute respiratoryRateSetting = 12;
            attribute oxygenFractionSetting = 60;
            attribute maxPressureThreshold = 40;
        }

        part patientMonitor : PatientMonitor;

        part suctionDevice : SuctionDevice {
            attribute suctionPressure = 120;
        }

        part cuffManometer : CuffPressureManometer {
            attribute targetPressure = 25;
        }

        // Connections
        connection ventilatorToTube
            connect ventilator.patientCircuit.delivered
            to endotrachealTube.proximalConnector.ventilation;

        connection tubeToVentilatorReturn
            connect endotrachealTube.proximalConnector.exhalation
            to ventilator.patientCircuit.returned;

        connection tubeToPatientAirway
            connect endotrachealTube.distalEnd.inspired
            to patient.trachealAccess.exhaled;

        connection patientToTubeExhalation
            connect patient.trachealAccess.exhaled
            to endotrachealTube.distalEnd.exhaled;

        connection cuffManometerToTube
            connect cuffManometer.cuffConnection.inflation
            to endotrachealTube.cuffInflationPort.inflation;

        connection ventilatorMonitoringToMonitor
            connect ventilator.monitoringOutput
            to patientMonitor.sensorInput;

        connection ventilatorAlarm
            connect ventilator.alarmOutput
            to patientMonitor.alarmOutput;

        connection suctionToDevice
            connect suctionDevice.suctionOutput
            to patient.airway;

        // Requirements satisfaction
        satisfy SecureAirwayEstablished by endotrachealTube;
        satisfy VentilationDelivered by ventilator;
        satisfy PatientMonitored by patientMonitor;
        satisfy AirwayPressureAlarm by ventilator;

        // Procedure invocation
        perform action intubationProcedure : IntubationProcedure {
            in patient = patient;
            in tube = endotrachealTube;
            in laryngoscope = laryngoscope;
            in ventilator = ventilator;
            in monitor = patientMonitor;
            in suction = suctionDevice;
            in manometer = cuffManometer;
        }
    }

}

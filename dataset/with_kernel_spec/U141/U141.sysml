package IntelligentAirPurificationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def AirQualityIndex :> Real;
    attribute def FilterLifePercentage :> Real;
    attribute def FanSpeedPercent :> Real;

    attribute def PowerOn;
    attribute def PowerOff;
    attribute def AutoModeEnable;
    attribute def AutoModeDisable;
    attribute def FilterReplaced;
    attribute def FilterReplacementAlert;

    item def Air;
    item def ContaminatedAir :> Air;
    item def PurifiedAir :> Air;
    item def Signal;

    port def AirFlowPort {
        inout air : Air;
    }
    port def PowerPort;
    port def ControlPort {
        inout signal : Signal;
    }

    action def SampleAir {
        out aqi : AirQualityIndex;
    }
    action def AdjustFanSpeed {
        in aqi : AirQualityIndex;
        out speed : FanSpeedPercent;
    }
    action def TrackFilterUsage {
        in operationalTime : DurationValue;
        in serviceLife : DurationValue;
        out remainingLife : FilterLifePercentage;
    }
    action def DisplayStatus {
        in aqi : AirQualityIndex;
        in remainingLife : FilterLifePercentage;
    }
    action def StandbyOperation {
        action sampleAir : SampleAir;
        action trackFilterUsage : TrackFilterUsage;
        action displayStatus : DisplayStatus;
    }
    action def AutoModeOperation {
        action sampleAir : SampleAir;
        action adjustFanSpeed : AdjustFanSpeed;
        action trackFilterUsage : TrackFilterUsage;
        action displayStatus : DisplayStatus;
    }

    part def PreFilter {
        port airIn : AirFlowPort;
        port airOut : AirFlowPort;
    }
    part def HEPAFilter {
        port airIn : AirFlowPort;
        port airOut : AirFlowPort;
        attribute remainingLife : FilterLifePercentage = 100.0;
        attribute operationalTime : DurationValue = 0 [h];
        attribute serviceLife : DurationValue = 4380 [h];
    }
    part def CarbonFilter {
        port airIn : AirFlowPort;
        port airOut : AirFlowPort;
    }
    part def AdjustableFan {
        port airIn : AirFlowPort;
        port airOut : AirFlowPort;
        port speedControl : ControlPort;
        port powerIn : PowerPort;
        attribute currentSpeed : FanSpeedPercent = 0;
    }
    part def AirQualitySensor {
        port airSampling : AirFlowPort;
        port dataOut : ControlPort;
        port powerIn : PowerPort;
        attribute currentReading : AirQualityIndex;
    }
    part def ControlUnit {
        port powerIn : PowerPort;
        port sensorDataIn : ControlPort;
        port fanControlOut : ControlPort;
        port uiDataOut : ControlPort;
        port uiCommandIn : ControlPort;
        attribute goodAqiThreshold : AirQualityIndex = 50;
        attribute poorAqiThreshold : AirQualityIndex = 100;
        attribute filterLifeThreshold : FilterLifePercentage = 10.0;
        attribute highSpeed : FanSpeedPercent = 100;
        attribute mediumSpeed : FanSpeedPercent = 60;
        attribute lowSpeed : FanSpeedPercent = 20;
    }
    part def UserInterface {
        port powerIn : PowerPort;
        port uiCommandOut : ControlPort;
        port uiDataIn : ControlPort;
    }

    part def AirPurifier {
        port powerIn : PowerPort;
        port airIntake : AirFlowPort;
        port airExhaust : AirFlowPort;

        part fan : AdjustableFan;
        part preFilter : PreFilter;
        part hepaFilter : HEPAFilter;
        part carbonFilter : CarbonFilter;
        part sensor : AirQualitySensor;
        part controlUnit : ControlUnit;
        part ui : UserInterface;

        connect airIntake to preFilter.airIn;
        connect preFilter.airOut to hepaFilter.airIn;
        connect hepaFilter.airOut to carbonFilter.airIn;
        connect carbonFilter.airOut to fan.airIn;
        connect fan.airOut to airExhaust;
        connect airIntake to sensor.airSampling;
        connect sensor.dataOut to controlUnit.sensorDataIn;
        connect controlUnit.fanControlOut to fan.speedControl;
        connect controlUnit.uiDataOut to ui.uiDataIn;
        connect ui.uiCommandOut to controlUnit.uiCommandIn;
        connect powerIn to controlUnit.powerIn;
        connect powerIn to ui.powerIn;
        connect powerIn to fan.powerIn;
        connect powerIn to sensor.powerIn;

        perform action standbyOperation : StandbyOperation;
        perform action autoModeOperation : AutoModeOperation;

        exhibit state purifierStates {
            entry; then off;

            state off;
            accept PowerOn then standby;

            state standby {
                entry assign fan.currentSpeed := 20;
                do standbyOperation;
            }
            accept AutoModeEnable then autoMode;
            accept PowerOff then off;
            accept when hepaFilter.remainingLife < 10.0
                do send new FilterReplacementAlert() to ui
                then filterMaintenance;

            state autoMode {
                do autoModeOperation;
            }
            accept AutoModeDisable then standby;
            accept PowerOff then off;
            accept when hepaFilter.remainingLife < 10.0
                do send new FilterReplacementAlert() to ui
                then filterMaintenance;

            state filterMaintenance {
                entry assign fan.currentSpeed := 0;
            }
            accept FilterReplaced then standby;
            accept PowerOff then off;
        }
    }

    requirement def AirPurificationReqDef {
        doc /* The system shall remove airborne contaminants including particulate matter, allergens, dust, VOCs, and odors. */
        attribute intakeContaminantLevel : AirQualityIndex;
        attribute exhaustContaminantLevel : AirQualityIndex;
        require constraint { exhaustContaminantLevel < intakeContaminantLevel }
    }
    requirement def HEPAFilterEfficiencyReqDef {
        doc /* The HEPA filter shall remove at least 99.97% of fine particles. */
        attribute particleRemovalEfficiency : Real;
        attribute minEfficiency : Real = 99.97;
        require constraint { particleRemovalEfficiency >= minEfficiency }
    }
    requirement def MultiStageFiltrationReqDef {
        doc /* The system shall pass air through a pre-filter, HEPA filter, and activated carbon filter in sequence. */
        attribute preFilterPresent : Boolean = true;
        attribute hepaFilterPresent : Boolean = true;
        attribute carbonFilterPresent : Boolean = true;
        require constraint { preFilterPresent and hepaFilterPresent and carbonFilterPresent }
    }
    requirement def AutoModeReqDef {
        doc /* The control unit shall automatically adjust fan speed based on air quality in Auto Mode. */
        attribute currentAqi : AirQualityIndex;
        attribute currentFanSpeed : FanSpeedPercent;
        attribute goodThreshold : AirQualityIndex = 50;
        attribute poorThreshold : AirQualityIndex = 100;
        require constraint {
            (currentAqi > poorThreshold implies currentFanSpeed >= 80) and
            (currentAqi > goodThreshold and currentAqi <= poorThreshold implies currentFanSpeed >= 40 and currentFanSpeed < 80) and
            (currentAqi <= goodThreshold implies currentFanSpeed < 40)
        }
    }
    requirement def FilterMaintenanceReqDef {
        doc /* The system shall alert the user when HEPA filter life drops below 10%. */
        attribute filterLife : FilterLifePercentage;
        attribute alertActive : Boolean;
        require constraint { filterLife < 10.0 implies alertActive == true }
    }
    requirement def UserInterfaceReqDef {
        doc /* The system shall provide a user interface to turn the device on or off and display air quality and filter remaining life. */
        attribute powerControl : Boolean;
        attribute displayAqi : Boolean;
        attribute displayFilterLife : Boolean;
        require constraint { powerControl and displayAqi and displayFilterLife }
    }
    requirement def PowerConnectionReqDef {
        doc /* The system shall be powered by a standard electrical connection. */
        attribute powerConnected : Boolean;
        require constraint { powerConnected == true }
    }

    part airPurifier : AirPurifier;
}

package 'Charcot Hydrotherapy System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def StartTherapy;
    item def StopTherapy;
    item def ResetSystem;

    item def TherapyProgrammed {
        attribute hotTemp : TemperatureValue;
        attribute coldTemp : TemperatureValue;
        attribute hotDuration : TimeValue;
        attribute coldDuration : TimeValue;
        attribute cycles : Natural;
    }

    item def WaterSample {
        attribute temperature : TemperatureValue;
        attribute pressure : Real;
    }

    action def PerformInitialization;
    action def DeliverHotWater;
    action def DeliverColdWater;
    action def PerformEmergencyShutdown;
    action def ShutdownSystem;
    action def PassWater;
    action def BlockWater;

    part def WaterSupply {
        out port supplyOut : WaterSample;
        action supplyWater {
            out water : WaterSample;
        }
    }

    part def WaterHeater {
        in port targetTemp : TemperatureValue;
        in port inlet : WaterSample;
        out port outlet : WaterSample;
        action heatWater {
            in inWater : WaterSample;
            in target : TemperatureValue;
            out heatedWater : WaterSample;
        }
    }

    part def WaterChiller {
        in port targetTemp : TemperatureValue;
        in port inlet : WaterSample;
        out port outlet : WaterSample;
        action chillWater {
            in inWater : WaterSample;
            in target : TemperatureValue;
            out chilledWater : WaterSample;
        }
    }

    part def WaterSplitter {
        in port inlet : WaterSample;
        out port hotOut : WaterSample;
        out port coldOut : WaterSample;
        action splitWater {
            in inWater : WaterSample;
            out hot : WaterSample;
            out cold : WaterSample;
        }
    }

    part def MixingValveAssembly {
        in port hotInlet : WaterSample;
        in port coldInlet : WaterSample;
        in port positionCommand : Real;
        out port outlet : WaterSample;
        action mixWater {
            in hot : WaterSample;
            in cold : WaterSample;
            in pos : Real;
            out mixed : WaterSample;
        }
    }

    part def SafetyShutoffValve {
        attribute maxTemp : TemperatureValue = 45 [degC];
        in port shutoffCmdIn : Real;
        in port inlet : WaterSample;
        out port outlet : WaterSample;
        action passWater;
        action blockWater;
    }

    part def PressureRegulator {
        in port targetPressure : Real;
        in port inlet : WaterSample;
        out port outlet : WaterSample;
        action regulatePressure {
            in inWater : WaterSample;
            in targetPress : Real;
            out regulatedWater : WaterSample;
        }
    }

    part def TemperatureSensor {
        in port inlet : WaterSample;
        out port outlet : WaterSample;
        out port reading : TemperatureValue;
        action senseTemperature {
            in sample : WaterSample;
            out temp : TemperatureValue;
            out passSample : WaterSample;
        }
    }

    part def PressureSensor {
        in port inlet : WaterSample;
        out port outlet : WaterSample;
        out port reading : Real;
        action sensePressure {
            in sample : WaterSample;
            out press : Real;
            out passSample : WaterSample;
        }
    }

    part def JetNozzleArray {
        in port inlet : WaterSample;
        action sprayWater {
            in waterSample : WaterSample;
        }
    }

    part def OperatorInterface {
        out port program : TherapyProgrammed;
        out port startCmd : StartTherapy;
        out port stopCmd : StopTherapy;
        out port resetCmd : ResetSystem;
    }

    part def TherapyControlUnit {
        attribute remainingCycles : Natural;

        in port programInput : TherapyProgrammed;
        in port startPort : StartTherapy;
        in port stopPort : StopTherapy;
        in port resetPort : ResetSystem;
        out port heaterTargetTemp : TemperatureValue;
        out port chillerTargetTemp : TemperatureValue;
        out port valvePosition : Real;
        out port safetyShutoffCommand : Real;
        out port regulatorPressure : Real;
        in port outputTemp : TemperatureValue;
        in port outputPressure : Real;

        perform action 'perform initialization' : PerformInitialization;
        perform action 'deliver hot water' : DeliverHotWater;
        perform action 'deliver cold water' : DeliverColdWater;
        perform action 'perform emergency shutdown' : PerformEmergencyShutdown;
        perform action 'shutdown system' : ShutdownSystem;

        state therapyStates {
            entry; then Standby;

            state Standby;
            accept StartTherapy via startPort
                then Initializing;

            state Initializing {
                do 'perform initialization';
                accept after 2 [s] then HotPhaseActive;
            }

            state HotPhaseActive {
                do 'deliver hot water';
                accept after programInput.hotDuration then ColdPhaseActive;
                accept when outputTemp > 45 [degC] or outputPressure > 5.0 then EmergencyShutdown;
                accept StopTherapy via stopPort then Standby;
            }

            state ColdPhaseActive {
                do 'deliver cold water';
                accept after programInput.coldDuration
                    if remainingCycles > 0
                    then HotPhaseActive;
                accept after programInput.coldDuration
                    if remainingCycles == 0
                    do 'shutdown system'
                    then Standby;
                accept when outputTemp > 45 [degC] or outputPressure > 5.0 then EmergencyShutdown;
                accept StopTherapy via stopPort then Standby;
            }

            state EmergencyShutdown {
                do 'perform emergency shutdown';
                accept ResetSystem via resetPort then Standby;
            }
        }
    }

    requirement def ScaldingPrevention {
        doc /* The output water temperature shall not exceed 45 degrees Celsius to prevent scalding. */
    }

    requirement def PressureSafety {
        doc /* The output water pressure shall not exceed 5.0 kPa for user safety. */
    }

    requirement def TherapyCycling {
        doc /* The system shall alternate between hot and cold water phases for the programmed number of cycles. */
    }

    part def CharcotShowerSystem {
        part supply : WaterSupply;
        part splitter : WaterSplitter;
        part heater : WaterHeater;
        part chiller : WaterChiller;
        part mixer : MixingValveAssembly;
        part safetyValve : SafetyShutoffValve;
        part regulator : PressureRegulator;
        part tempSensor : TemperatureSensor;
        part pressSensor : PressureSensor;
        part jets : JetNozzleArray;
        part control : TherapyControlUnit;
        part operator : OperatorInterface;

        connect supply.supplyOut to splitter.inlet;
        connect splitter.hotOut to heater.inlet;
        connect splitter.coldOut to chiller.inlet;
        connect heater.outlet to mixer.hotInlet;
        connect chiller.outlet to mixer.coldInlet;
        connect mixer.outlet to safetyValve.inlet;
        connect safetyValve.outlet to regulator.inlet;
        connect regulator.outlet to tempSensor.inlet;
        connect tempSensor.outlet to pressSensor.inlet;
        connect pressSensor.outlet to jets.inlet;

        connect control.heaterTargetTemp to heater.targetTemp;
        connect control.chillerTargetTemp to chiller.targetTemp;
        connect control.valvePosition to mixer.positionCommand;
        connect control.safetyShutoffCommand to safetyValve.shutoffCmdIn;
        connect control.regulatorPressure to regulator.targetPressure;
        connect operator.program to control.programInput;
        connect operator.startCmd to control.startPort;
        connect operator.stopCmd to control.stopPort;
        connect operator.resetCmd to control.resetPort;

        connect tempSensor.reading to control.outputTemp;
        connect pressSensor.reading to control.outputPressure;

        satisfy ScaldingPrevention;
        satisfy PressureSafety;
        satisfy TherapyCycling;
    }

    part hydroSystem : CharcotShowerSystem;
}

package RheotraumaTestSystem {
    private import ScalarValues::*;

    unit def Pa;
    unit def mL_per_min;
    unit def degC;
    unit def rpm;

    attribute def ShearStress :> Real;
    attribute def FlowRate :> Real;
    attribute def Temperature :> Real;
    attribute def PumpSpeed :> Real;
    attribute def DamageIndex :> Real;
    attribute def Viability :> Real;

    item def Fluid;
    item def BloodSample;

    attribute def StartExperimentSignal;
    attribute def StopExperimentSignal;
    attribute def CriticalFaultSignal;
    attribute def CalibrationCompleteSignal;
    attribute def DataProcessingCompleteSignal;

    part def ShearChamber {
        port fluidInPort { in fluid : Fluid; }
        port fluidOutPort { out fluid : Fluid; }
        port sampleInPort { in sample : BloodSample; }
        port sampleOutPort { out sample : BloodSample; }
    }

    part def FluidReservoir {
        port fluidOutPort { out fluid : Fluid; }
        port fluidInPort { in fluid : Fluid; }
    }

    part def PrecisionPump {
        port fluidInPort { in fluid : Fluid; }
        port fluidOutPort { out fluid : Fluid; }
        port controlPort { in speed : PumpSpeed; }
    }

    part def DamageAnalyzer {
        port sampleInPort { in sample : BloodSample; }
        attribute damageIndex : DamageIndex;
        attribute viability : Viability;
        action analyzeSample { in sample : BloodSample; }
    }

    part def ShearStressSensor {
        port measurementPort { out stress : ShearStress; }
    }

    part def FlowRateSensor {
        port measurementPort { out flowRate : FlowRate; }
    }

    part def TemperatureController {
        port measurementPort { out temp : Temperature; }
        port controlPort { in targetTemp : Temperature; }
    }

    part def SystemController {
        port shearStressPort { in stress : ShearStress; }
        port flowRatePort { in flowRate : FlowRate; }
        port tempPort { in temp : Temperature; }
        port pumpControlPort { out speed : PumpSpeed; }
        port tempControlPort { out targetTemp : Temperature; }

        attribute targetShearStress : ShearStress;
        attribute targetTemperature : Temperature := 37.0;

        state def ControllerStates;
        state controllerStates : ControllerStates {
            entry; then initialization;
            state initialization;
            transition init_to_standby
                first initialization
                accept CalibrationCompleteSignal
                then standby;
            state standby;
            transition standby_to_running
                first standby
                accept StartExperimentSignal
                then running;
            state running {
                do action adjustPumpSpeed { /* adjust pump speed based on shear stress and flow rate */ }
                do action regulateTemperature { /* regulate temperature */ }
            }
            transition running_to_processing
                first running
                accept StopExperimentSignal
                then dataProcessing;
            state dataProcessing;
            transition processing_to_standby
                first dataProcessing
                accept DataProcessingCompleteSignal
                then standby;
            
            transition standby_to_emergency
                first standby
                accept CriticalFaultSignal
                then emergencyShutdown;
            transition running_to_emergency
                first running
                accept CriticalFaultSignal
                then emergencyShutdown;
            transition processing_to_emergency
                first dataProcessing
                accept CriticalFaultSignal
                then emergencyShutdown;
            state emergencyShutdown;
            then done;
        }
    }

    part def RheotraumaTestSystem {
        part shearChamber : ShearChamber;
        part fluidReservoir : FluidReservoir;
        part precisionPump : PrecisionPump;
        part damageAnalyzer : DamageAnalyzer;
        part shearStressSensor : ShearStressSensor;
        part flowRateSensor : FlowRateSensor;
        part temperatureController : TemperatureController;
        part systemController : SystemController;

        flow fluidFlow1 of Fluid from fluidReservoir.fluidOutPort.fluid to precisionPump.fluidInPort.fluid;
        flow fluidFlow2 of Fluid from precisionPump.fluidOutPort.fluid to shearChamber.fluidInPort.fluid;
        flow fluidFlow3 of Fluid from shearChamber.fluidOutPort.fluid to fluidReservoir.fluidInPort.fluid;

        flow sampleFlow of BloodSample from shearChamber.sampleOutPort.sample to damageAnalyzer.sampleInPort.sample;

        flow stressFlow of ShearStress from shearStressSensor.measurementPort.stress to systemController.shearStressPort.stress;
        flow flowRateFlow of FlowRate from flowRateSensor.measurementPort.flowRate to systemController.flowRatePort.flowRate;
        flow tempFlow of Temperature from temperatureController.measurementPort.temp to systemController.tempPort.temp;

        flow pumpSpeedFlow of PumpSpeed from systemController.pumpControlPort.speed to precisionPump.controlPort.speed;
        flow targetTempFlow of Temperature from systemController.tempControlPort.targetTemp to temperatureController.controlPort.targetTemp;
    }

    requirement RheotraumaQuantification {
        doc /* The system shall expose blood samples to controlled shear stress and quantify resulting mechanical damage. */
    }
    requirement ShearStressControl {
        doc /* The system shall maintain target shear stress by adjusting pump speed based on feedback from shear stress and flow rate sensors. */
    }
    requirement TemperatureControl {
        doc /* The system shall maintain experimental temperature at 37 degrees Celsius with stable control. */
    }
    requirement EmergencyShutdown {
        doc /* The system shall perform an emergency shutdown upon detection of critical faults. */
    }

    part testSystem : RheotraumaTestSystem;
    satisfy RheotraumaQuantification by testSystem;
    satisfy ShearStressControl by testSystem;
    satisfy TemperatureControl by testSystem;
    satisfy EmergencyShutdown by testSystem;
}

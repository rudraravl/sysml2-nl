package PumpedStorageHydroelectricSystem {

    import ScalarValues::*;

    // =====================================================
    // Value Types (with unit documentation)
    // =====================================================

    value type PressureValue {
        doc "Hydraulic pressure [Pa]";
    }

    value type FlowRateValue {
        doc "Volumetric flow rate [m3/s]";
    }

    value type PowerValue {
        doc "Power [W]";
    }

    value type RotationalSpeedValue {
        doc "Angular speed [rad/s]";
    }

    value type TorqueValue {
        doc "Torque [N*m]";
    }

    value type ElevationValue {
        doc "Elevation above datum [m]";
    }

    value type VoltageValue {
        doc "Electrical potential [V]";
    }

    value type HeadValue {
        doc "Hydraulic head [m]";
    }

    value type EfficiencyValue {
        doc "Dimensionless efficiency [1]";
    }

    value type VolumeValue {
        doc "Volume [m3]";
    }

    value type DensityValue {
        doc "Mass density [kg/m3]";
    }

    value type DiameterValue {
        doc "Diameter [m]";
    }

    // =====================================================
    // Item Definitions
    // =====================================================

    item def Water {
        attribute density : DensityValue;
        attribute temperature : Real;
    }

    item def PressurizedWater :> Water {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def HighHeadWater :> PressurizedWater;

    // =====================================================
    // Port Definitions
    // =====================================================

    port def FluidPort {
        in out item : Water;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def ShaftPort {
        in out attribute torque : TorqueValue;
        in out attribute speed : RotationalSpeedValue;
    }

    port def ElectricalPort {
        in out attribute power : PowerValue;
        in out attribute voltage : VoltageValue;
    }

    port def SensorPort {
        out attribute pressure : PressureValue;
        out attribute flowRate : FlowRateValue;
        out attribute power : PowerValue;
    }

    // =====================================================
    // Connection Definitions
    // =====================================================

    connection def FluidPipe {
        end source : FluidPort;
        end target : FluidPort;
    }

    connection def ShaftCoupling {
        end drive : ShaftPort;
        end driven : ShaftPort;
    }

    connection def PowerCable {
        end a : ElectricalPort;
        end b : ElectricalPort;
    }

    connection def SignalWire {
        end sensor : SensorPort;
        end controller : SensorPort;
    }

    // =====================================================
    // Action Definitions
    // =====================================================

    action def RampUp {
        doc "Gradually increase rotational speed to operating point.";
        in targetSpeed : RotationalSpeedValue;
        in currentSpeed : RotationalSpeedValue;
        out achievedSpeed : RotationalSpeedValue;
    }

    action def Decelerate {
        doc "Gradually reduce rotational speed to rest.";
        in currentSpeed : RotationalSpeedValue;
        out achievedSpeed : RotationalSpeedValue;
    }

    action def Accelerate {
        doc "Bring turbine runner up to synchronous speed.";
        in targetSpeed : RotationalSpeedValue;
        in currentSpeed : RotationalSpeedValue;
        out achievedSpeed : RotationalSpeedValue;
    }

    action def MonitorPump {
        doc "Continuously monitor pump discharge pressure and flow.";
        in pressure : PressureValue;
        in flowRate : FlowRateValue;
        in highPressureThreshold : PressureValue;
        out pressureAlarm : Boolean;
        out flowAlarm : Boolean;
    }

    action def MonitorTurbine {
        doc "Continuously monitor turbine output power and head.";
        in power : PowerValue;
        in head : HeadValue;
        in powerOverloadThreshold : PowerValue;
        out powerOverloadAlarm : Boolean;
    }

    // =====================================================
    // State Machine Definitions
    // =====================================================

    state def PumpOperatingStates {
        doc "Operating states for the pumping subsystem.";

        state idle {
            doc "Pump motor de-energized, no flow.";
            entry { self.motorPower = 0; }
        }
        state starting {
            doc "Motor energized, ramping up to full speed.";
            entry { self.motorPower = self.ratedPumpPower; }
            do action rampUp : RampUp;
        }
        state running {
            doc "Pump at full load delivering fluid to upper reservoir.";
            entry { self.motorPower = self.ratedPumpPower; }
            do action monitor : MonitorPump;
        }
        state stopping {
            doc "Reducing speed and flow before shutdown.";
            entry { self.motorPower = 0; }
            do action decel : Decelerate;
        }

        transition from idle to starting when self.startCommand;
        transition from starting to running when self.atFullSpeed;
        transition from running to stopping when self.stopCommand;
        transition from stopping to idle when self.motorStopped;
        transition from running to stopping when self.highPressureAlarm;
    }

    state def TurbineOperatingStates {
        doc "Operating states for the generation subsystem.";

        state idle {
            doc "Turbine stopped, guide vanes closed.";
            entry { self.guideVanesOpen = false; }
        }
        state starting {
            doc "Guide vanes opening, runner accelerating.";
            entry { self.guideVanesOpen = true; }
            do action accel : Accelerate;
        }
        state running {
            doc "Turbine synchronized, generating electrical power.";
            entry { self.generatorBreakerClosed = true; }
            do action monitor : MonitorTurbine;
        }
        state stopping {
            doc "Guide vanes closing, runner decelerating.";
            entry { self.generatorBreakerClosed = false; }
            do action decel : Decelerate;
        }

        transition from idle to starting when self.startCommand;
        transition from starting to running when self.synchronized;
        transition from running to stopping when self.stopCommand;
        transition from stopping to idle when self.turbineStopped;
        transition from running to stopping when self.powerOverloadAlarm;
    }

    // =====================================================
    // Requirement Definitions
    // =====================================================

    requirement def EnergyStorageRequirement {
        doc "The system shall store electrical energy by pumping fluid to a higher elevation.";
        attribute ratedPumpPower : PowerValue;
        attribute maxHead : HeadValue;
        constraint { ratedPumpPower > 0 and maxHead > 0 }
    }

    requirement def EnergyGenerationRequirement {
        doc "The system shall recover stored energy by routing fluid through a turbine and generator.";
        attribute ratedGenerationPower : PowerValue;
        attribute minTurbineEfficiency : EfficiencyValue;
        constraint { ratedGenerationPower > 0 and minTurbineEfficiency >= 0 }
    }

    requirement def SafetyMonitoringRequirement {
        doc "The system shall monitor pressure after the pump and power load on the turbine.";
        attribute maxPumpDischargePressure : PressureValue;
        attribute maxTurbinePower : PowerValue;
        constraint { maxPumpDischargePressure > 0 and maxTurbinePower > 0 }
    }

    requirement def EulerTurbomachineryRequirement {
        doc "Pump and turbine performance shall be consistent with Euler's equations for turbomachinery.";
        attribute pumpSpecificSpeed : RotationalSpeedValue;
        attribute turbineSpecificSpeed : RotationalSpeedValue;
        constraint { pumpSpecificSpeed > 0 and turbineSpecificSpeed > 0 }
    }

    // =====================================================
    // Component Part Definitions
    // =====================================================

    part def Reservoir {
        doc "A fluid reservoir at a given elevation.";
        attribute elevation : ElevationValue;
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        port fluidPort : FluidPort;
    }

    part def LowerReservoir :> Reservoir {
        doc "Low-level source/sink reservoir.";
    }

    part def UpperReservoir :> Reservoir {
        doc "Intermediate high-elevation storage reservoir.";
    }

    part def Impeller {
        doc "Rapidly spinning pump component with blades that transfers energy to the fluid.";
        attribute bladeCount : Integer;
        attribute diameter : DiameterValue;
        attribute maxSpeed : RotationalSpeedValue;
        attribute currentSpeed : RotationalSpeedValue;
        port shaftIn : ShaftPort;
        port fluidOut : FluidPort;
    }

    part def Volute {
        doc "Snail-shaped pump casing that converts high fluid velocity into high pressure.";
        attribute inletDiameter : DiameterValue;
        attribute outletDiameter : DiameterValue;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def CentrifugalPump {
        doc "Centrifugal pump driven by an electric motor to move fluid uphill.";
        part impeller : Impeller;
        part volute : Volute;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port shaftIn : ShaftPort;
        attribute ratedHead : HeadValue;
        attribute ratedFlow : FlowRateValue;
        attribute efficiency : EfficiencyValue;
        attribute outputHead : HeadValue;

        connection : inletToImpeller : FluidPipe {
            end source = fluidIn;
            end target = impeller.fluidOut;
        }
        connection : impellerToVolute : FluidPipe {
            end source = impeller.fluidOut;
            end target = volute.fluidIn;
        }
        connection : voluteToOutlet : FluidPipe {
            end source = volute.fluidOut;
            end target = fluidOut;
        }
        connection : shaftToImpeller : ShaftCoupling {
            end drive = shaftIn;
            end driven = impeller.shaftIn;
        }
    }

    part def ElectricMotor {
        doc "Converts electrical energy into rotational mechanical energy.";
        port powerIn : ElectricalPort;
        port shaftOut : ShaftPort;
        attribute ratedPower : PowerValue;
        attribute ratedVoltage : VoltageValue;
        attribute efficiency : EfficiencyValue;
        attribute currentPower : PowerValue;
        attribute currentSpeed : RotationalSpeedValue;
    }

    part def Runner {
        doc "Turbine rotating part whose blades are struck by the moving fluid.";
        attribute bladeCount : Integer;
        attribute diameter : DiameterValue;
        attribute maxSpeed : RotationalSpeedValue;
        attribute currentSpeed : RotationalSpeedValue;
        port fluidIn : FluidPort;
        port shaftOut : ShaftPort;
    }

    part def DraftTube {
        doc "Diverging pipe that recovers remaining kinetic energy from turbine discharge.";
        attribute inletDiameter : DiameterValue;
        attribute outletDiameter : DiameterValue;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def HydraulicTurbine {
        doc "Hydraulic turbine that converts fluid energy into shaft rotation.";
        part runner : Runner;
        part draftTube : DraftTube;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port shaftOut : ShaftPort;
        attribute ratedHead : HeadValue;
        attribute ratedFlow : FlowRateValue;
        attribute efficiency : EfficiencyValue;
        attribute outputPower : PowerValue;

        connection : inletToRunner : FluidPipe {
            end source = fluidIn;
            end target = runner.fluidIn;
        }
        connection : runnerToDraft : FluidPipe {
            end source = runner.fluidIn;
            end target = draftTube.fluidIn;
        }
        connection : draftToOutlet : FluidPipe {
            end source = draftTube.fluidOut;
            end target = fluidOut;
        }
        connection : runnerToShaft : ShaftCoupling {
            end drive = runner.shaftOut;
            end driven = shaftOut;
        }
    }

    part def Generator {
        doc "Converts mechanical rotation into electrical power.";
        port shaftIn : ShaftPort;
        port powerOut : ElectricalPort;
        attribute ratedPower : PowerValue;
        attribute ratedVoltage : VoltageValue;
        attribute efficiency : EfficiencyValue;
        attribute outputPower : PowerValue;
    }

    part def PressureSensor {
        doc "Measures fluid pressure at a specific point.";
        port fluidTap : FluidPort;
        port signalOut : SensorPort;
        attribute maxPressure : PressureValue;
        attribute reading : PressureValue;
    }

    part def FlowMeter {
        doc "Measures volumetric flow rate.";
        port fluidTap : FluidPort;
        port signalOut : SensorPort;
        attribute reading : FlowRateValue;
    }

    part def SystemController {
        doc "Coordinates pump and turbine operation with safety monitoring.";
        port pumpSensorIn : SensorPort;
        port turbineSensorIn : SensorPort;
        port motorPowerOut : ElectricalPort;
        port generatorBreaker : ElectricalPort;
        attribute systemState : String;
        attribute highPressureThreshold : PressureValue;
        attribute powerOverloadThreshold : PowerValue;
        attribute ratedPumpPower : PowerValue;
        attribute motorPower : PowerValue;
        attribute guideVanesOpen : Boolean;
        attribute generatorBreakerClosed : Boolean;
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
        attribute atFullSpeed : Boolean;
        attribute synchronized : Boolean;
        attribute motorStopped : Boolean;
        attribute turbineStopped : Boolean;
        attribute highPressureAlarm : Boolean;
        attribute powerOverloadAlarm : Boolean;

        perform PumpOperatingStates;
        perform TurbineOperatingStates;
    }

    // =====================================================
    // Top-Level System
    // =====================================================

    part def PumpedStoragePlant {
        doc "Complete hydraulic energy storage and generation plant.";

        // --- Requirements ---
        requirement : storageRequirement : EnergyStorageRequirement {
            attribute ratedPumpPower = 500000;
            attribute maxHead = 100;
        }
        requirement : generationRequirement : EnergyGenerationRequirement {
            attribute ratedGenerationPower = 450000;
            attribute minTurbineEfficiency = 0.85;
        }
        requirement : safetyRequirement : SafetyMonitoringRequirement {
            attribute maxPumpDischargePressure = 1200000;
            attribute maxTurbinePower = 600000;
        }
        requirement : eulerRequirement : EulerTurbomachineryRequirement {
            attribute pumpSpecificSpeed = 60;
            attribute turbineSpecificSpeed = 50;
        }

        // --- Pumping loop parts ---
        part : lowerReservoir : LowerReservoir {
            attribute elevation = 0;
            attribute capacity = 10000;
        }
        part : upperReservoir : UpperReservoir {
            attribute elevation = 100;
            attribute capacity = 10000;
        }
        part : motor : ElectricMotor {
            attribute ratedPower = 500000;
            attribute ratedVoltage = 690;
            attribute efficiency = 0.95;
        }
        part : pump : CentrifugalPump {
            attribute ratedHead = 100;
            attribute ratedFlow = 0.5;
            attribute efficiency = 0.85;
        }

        // --- Generation loop parts ---
        part : turbine : HydraulicTurbine {
            attribute ratedHead = 100;
            attribute ratedFlow = 0.5;
            attribute efficiency = 0.90;
        }
        part : generator : Generator {
            attribute ratedPower = 450000;
            attribute ratedVoltage = 690;
            attribute efficiency = 0.96;
        }

        // --- Sensors ---
        part : pumpDischargePressureSensor : PressureSensor {
            attribute maxPressure = 1500000;
        }
        part : pumpFlowMeter : FlowMeter;
        part : turbineInletPressureSensor : PressureSensor {
            attribute maxPressure = 1500000;
        }
        part : turbineFlowMeter : FlowMeter;

        // --- Controller ---
        part : controller : SystemController {
            attribute highPressureThreshold = 1200000;
            attribute powerOverloadThreshold = 600000;
            attribute ratedPumpPower = 500000;
        }

        // --- Pumping loop connections ---
        connection : lowerToPump : FluidPipe {
            end source = lowerReservoir.fluidPort;
            end target = pump.fluidIn;
        }
        connection : pumpToPressureSensor : FluidPipe {
            end source = pump.fluidOut;
            end target = pumpDischargePressureSensor.fluidTap;
        }
        connection : pressureSensorToFlowMeter : FluidPipe {
            end source = pumpDischargePressureSensor.fluidTap;
            end target = pumpFlowMeter.fluidTap;
        }
        connection : pumpToUpper : FluidPipe {
            end source = pump.fluidOut;
            end target = upperReservoir.fluidPort;
        }
        connection : motorToPumpShaft : ShaftCoupling {
            end drive = motor.shaftOut;
            end driven = pump.shaftIn;
        }
        connection : motorPowerFeed : PowerCable {
            end a = controller.motorPowerOut;
            end b = motor.powerIn;
        }

        // --- Generation loop connections ---
        connection : upperToTurbinePressure : FluidPipe {
            end source = upperReservoir.fluidPort;
            end target = turbineInletPressureSensor.fluidTap;
        }
        connection : turbinePressureToTurbine : FluidPipe {
            end source = turbineInletPressureSensor.fluidTap;
            end target = turbine.fluidIn;
        }
        connection : turbineToFlowMeter : FluidPipe {
            end source = turbine.fluidOut;
            end target = turbineFlowMeter.fluidTap;
        }
        connection : turbineFlowToLower : FluidPipe {
            end source = turbine.fluidOut;
            end target = lowerReservoir.fluidPort;
        }
        connection : turbineToGeneratorShaft : ShaftCoupling {
            end drive = turbine.shaftOut;
            end driven = generator.shaftIn;
        }
        connection : generatorBreakerLink : PowerCable {
            end a = generator.powerOut;
            end b = controller.generatorBreaker;
        }

        // --- Signal connections ---
        connection : pumpPressureSignal : SignalWire {
            end sensor = pumpDischargePressureSensor.signalOut;
            end controller = controller.pumpSensorIn;
        }
        connection : pumpFlowSignal : SignalWire {
            end sensor = pumpFlowMeter.signalOut;
            end controller = controller.pumpSensorIn;
        }
        connection : turbinePressureSignal : SignalWire {
            end sensor = turbineInletPressureSensor.signalOut;
            end controller = controller.turbineSensorIn;
        }
        connection : turbineFlowSignal : SignalWire {
            end sensor = turbineFlowMeter.signalOut;
            end controller = controller.turbineSensorIn;
        }
    }

}

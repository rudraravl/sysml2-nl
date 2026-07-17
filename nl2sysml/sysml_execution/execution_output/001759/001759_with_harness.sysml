package CentrifugalFanSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def RotationalSpeedValue :> AngularVelocityValue;
    attribute def VolumetricFlowRateValue :> VolumeFlowRateValue;
    attribute def PressureDifferenceValue :> PressureValue;
    attribute def EfficiencyRatio :> Real;

    enum def OperatingMode {
        off;
        startup;
        normal;
        shutdown;
        fault;
    }

    item def Air {
        attribute density : DensityValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    port def AirFlowPort {
        in item airIn : Air;
        out item airOut : Air;
        attribute flowRate : VolumetricFlowRateValue;
    }

    port def PowerInputPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute powerDraw : PowerValue;
    }

    port def ControlSignalPort {
        attribute speedCommand : RotationalSpeedValue;
        attribute operatingMode : OperatingMode;
    }

    part def Impeller {
        attribute diameter : LengthValue;
        attribute bladeCount : Integer;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute mass : MassValue;
        attribute bladeAngle : Real;

        port mechanicalInput {
            attribute torque : Real;
            attribute speed : RotationalSpeedValue;
        }
    }

    part def ScrollHousing {
        attribute inletDiameter : LengthValue;
        attribute outletDiameter : LengthValue;
        attribute scrollWidth : LengthValue;
        attribute mass : MassValue;

        port airInlet : AirFlowPort;
        port airOutlet : AirFlowPort;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue;
        attribute ratedSpeed : RotationalSpeedValue;
        attribute efficiency : EfficiencyRatio;
        attribute mass : MassValue;

        port electricalInput : PowerInputPort;
        port mechanicalOutput {
            attribute torque : Real;
            attribute speed : RotationalSpeedValue;
        }
    }

    part def DriveShaft {
        attribute diameter : LengthValue;
        attribute length : LengthValue;
        attribute material : String;
        attribute mass : MassValue;
    }

    part def BearingAssembly {
        attribute bearingType : String;
        attribute loadRating : ForceValue;
        attribute mass : MassValue;
    }

    part def ControlModule {
        attribute controllerType : String;
        attribute mass : MassValue;

        port controlOutput : ControlSignalPort;
        port sensorInput {
            attribute speedFeedback : RotationalSpeedValue;
            attribute vibrationLevel : Real;
        }
    }

    action def AccelerateAirflow {
        in airInput : Air;
        in impellerSpeed : RotationalSpeedValue;
        in impellerDiameter : LengthValue;
        out airOutput : Air;
        out pressureIncrease : PressureDifferenceValue;
        out volumeFlow : VolumetricFlowRateValue;
    }

    action def ConvertElectricalPower {
        in electricalPower : PowerValue;
        in targetSpeed : RotationalSpeedValue;
        out mechanicalTorque : Real;
        out shaftSpeed : RotationalSpeedValue;
        out efficiency : EfficiencyRatio;
    }

    action def MonitorPerformance {
        in currentSpeed : RotationalSpeedValue;
        in flowRate : VolumetricFlowRateValue;
        in powerConsumption : PowerValue;
        in vibration : Real;
        out status : OperatingMode;
        out healthIndicator : Real;
    }

    action def OperateFan {
        first start;
        then merge continueOperation;

        then action monitor : MonitorPerformance {
            in currentSpeed : RotationalSpeedValue;
            in flowRate : VolumetricFlowRateValue;
            in powerConsumption : PowerValue;
            in vibration : Real;
            out status : OperatingMode;
        }

        then decide;
            if monitor.status == OperatingMode::normal then moveAir;
            if monitor.status == OperatingMode::fault then handleFault;
            if monitor.status == OperatingMode::off then done;

        action moveAir parallel {
            action convertPower : ConvertElectricalPower;
            then action accelerateAir : AccelerateAirflow;
        }
        then continueOperation;

        action handleFault {
            doc "Execute fault handling and safety shutdown procedures";
        }
        then done;
    }

    part def CentrifugalFan {
        doc /* A centrifugal fan system that moves air by converting rotational 
             * kinetic energy from a motor-driven impeller into increased static 
             * pressure and velocity of the air stream. The impeller accelerates 
             * air radially outward into a scroll housing that converts velocity 
             * into pressure for discharge through the outlet.
             */

        attribute totalMass : MassValue;
        attribute maxFlowRate : VolumetricFlowRateValue;
        attribute maxPressureRise : PressureDifferenceValue;
        attribute overallEfficiency : EfficiencyRatio;
        attribute operatingMode : OperatingMode;

        port airInlet : AirFlowPort;
        port airOutlet : AirFlowPort;
        port powerInput : PowerInputPort;
        port controlInterface : ControlSignalPort;

        part impeller : Impeller {
            attribute :>> diameter = 350.0 [mm];
            attribute :>> bladeCount = 16;
            attribute :>> mass = 6.8 [kg];
            attribute :>> bladeAngle = 45.0;
        }

        part housing : ScrollHousing {
            attribute :>> inletDiameter = 300.0 [mm];
            attribute :>> outletDiameter = 250.0 [mm];
            attribute :>> scrollWidth = 180.0 [mm];
            attribute :>> mass = 22.5 [kg];
        }

        part motor : ElectricMotor {
            attribute :>> ratedPower = 3000.0 [W];
            attribute :>> ratedSpeed = 2900.0 [rpm];
            attribute :>> efficiency = 0.89;
            attribute :>> mass = 15.2 [kg];
        }

        part shaft : DriveShaft {
            attribute :>> diameter = 30.0 [mm];
            attribute :>> length = 200.0 [mm];
            attribute :>> material = "Stainless Steel 316";
            attribute :>> mass = 2.1 [kg];
        }

        part bearings : BearingAssembly {
            attribute :>> bearingType = "Deep Groove Ball Bearing";
            attribute :>> loadRating = 8500.0 [N];
            attribute :>> mass = 1.2 [kg];
        }

        part controller : ControlModule {
            attribute :>> controllerType = "Variable Frequency Drive";
            attribute :>> mass = 0.8 [kg];
        }

        connection motorToShaft connect motor.mechanicalOutput to shaft;
        connection shaftToImpeller connect shaft to impeller.mechanicalInput;
        connection housingAirInlet connect housing.airInlet to airInlet;
        connection housingAirOutlet connect housing.airOutlet to airOutlet;
        connection motorPowerConnection connect motor.electricalInput to powerInput;
        connection controllerConnection connect controller.controlOutput to controlInterface;

        item flow airFlow from airInlet.airIn to housing.airInlet.airIn;
        item flow acceleratedAir from housing.airOutlet.airOut to airOutlet.airOut;

        assert constraint totalMassCalculation {
            totalMass == impeller.mass + housing.mass + motor.mass + 
                        shaft.mass + bearings.mass + controller.mass
        }

        assert constraint flowContinuity {
            airInlet.flowRate == airOutlet.flowRate
        }

        assert constraint pressureRiseRelation {
            maxPressureRise == airOutlet.airOut.pressure - airInlet.airIn.pressure
        }

        perform action operation : OperateFan;
    }

    requirement <'REQ-CF-001'> primaryFunction {
        doc /* The centrifugal fan system shall move air from the inlet to the 
             * outlet by imparting kinetic energy through a rotating impeller, 
             * which accelerates air radially outward. The scroll housing then 
             * converts the velocity energy into static pressure rise, enabling 
             * air movement against system resistance.
             */
        subject fan : CentrifugalFan;
    }

    requirement <'REQ-CF-002'> flowCapacity {
        doc /* The centrifugal fan shall deliver a minimum volumetric flow rate 
             * of 2000 cubic meters per hour at rated operating conditions.
             */
        subject fan : CentrifugalFan;
        assert constraint {
            fan.maxFlowRate >= 2000.0 [m^3/h]
        }
    }

    requirement <'REQ-CF-003'> pressureGeneration {
        doc /* The centrifugal fan shall generate a minimum static pressure 
             * rise of 1000 Pascals between inlet and outlet at rated flow.
             */
        subject fan : CentrifugalFan;
        assert constraint {
            fan.maxPressureRise >= 1000.0 [Pa]
        }
    }

    requirement <'REQ-CF-004'> systemEfficiency {
        doc /* The centrifugal fan system shall operate at a minimum overall 
             * efficiency of 70% at rated conditions, accounting for motor 
             * and aerodynamic losses.
             */
        subject fan : CentrifugalFan;
        assert constraint {
            fan.overallEfficiency >= 0.70
        }
    }

    requirement <'REQ-CF-005'> massLimit {
        doc /* The total mass of the centrifugal fan assembly shall not exceed 
             * 55 kilograms for structural and installation requirements.
             */
        subject fan : CentrifugalFan;
        assert constraint {
            fan.totalMass <= 55.0 [kg]
        }
    }

    part industrialVentilationFan : CentrifugalFan {
        attribute :>> totalMass = 48.6 [kg];
        attribute :>> maxFlowRate = 2400.0 [m^3/h];
        attribute :>> maxPressureRise = 1200.0 [Pa];
        attribute :>> overallEfficiency = 0.75;
    }

    satisfy primaryFunction by industrialVentilationFan;
    satisfy flowCapacity by industrialVentilationFan;
    satisfy pressureGeneration by industrialVentilationFan;
    satisfy systemEfficiency by industrialVentilationFan;
    satisfy massLimit by industrialVentilationFan;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import CentrifugalFanSystem::*;

    action orchestrator {
        item testAirInput : Air {
            attribute density : DensityValue;
            attribute pressure : PressureValue;
            attribute temperature : TemperatureValue;
        }
        attribute testImpellerSpeed : RotationalSpeedValue;
        attribute testImpellerDiameter : LengthValue;
        action actionProbe : AccelerateAirflow {
            in airInput = testAirInput;
            in impellerSpeed = testImpellerSpeed;
            in impellerDiameter = testImpellerDiameter;
        }
        first actionProbe;
    }
}

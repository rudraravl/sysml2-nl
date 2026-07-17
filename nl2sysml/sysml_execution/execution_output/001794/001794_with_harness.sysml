package KarassikCentrifugalPumpSystem {
    attribute def StartCommand;
    attribute def StopCommand;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def FlowRateValue :> Real;
    attribute def PressureValue :> Real;
    attribute def HeadValue :> Real;
    attribute def PowerValue :> Real;
    attribute def RotationalSpeedValue :> Real;
    attribute def EfficiencyValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def ViscosityValue :> Real;
    attribute def DensityValue :> Real;
    attribute def TorqueValue :> Real;

    item def ProcessFluid {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
        attribute vaporPressure : PressureValue;
    }

    port def HydraulicPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }

    port def MechanicalPort {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute power : PowerValue;
    }

    port def ElectricalPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
    }

    part def Impeller {
        attribute diameter : Real;
        attribute bladeCount : Integer;
        attribute bladeAngle : Real;
        attribute hydraulicEfficiency : EfficiencyValue;

        port shaftInput : MechanicalPort;
        port fluidInlet : HydraulicPort;
        port fluidOutlet : HydraulicPort;

        assert constraint energyTransfer {
            fluidOutlet.pressure > fluidInlet.pressure and
            shaftInput.power * hydraulicEfficiency >= 
                (fluidOutlet.pressure - fluidInlet.pressure) * fluidOutlet.flowRate
        }
    }

    part def Volute {
        attribute throatArea : Real;
        attribute diffuserAngle : Real;
        attribute pressureRecoveryFactor : Real;

        port inlet : HydraulicPort;
        port outlet : HydraulicPort;

        assert constraint pressureConversion {
            outlet.pressure >= inlet.pressure * pressureRecoveryFactor
        }
    }

    part def Shaft {
        attribute diameter : Real;
        attribute length : Real;
        attribute material : String;
        attribute mechanicalEfficiency : EfficiencyValue;

        port driverEnd : MechanicalPort;
        port impellerEnd : MechanicalPort;

        assert constraint powerTransmission {
            impellerEnd.power == driverEnd.power * mechanicalEfficiency and
            impellerEnd.speed == driverEnd.speed
        }
    }

    part def MechanicalSeal {
        attribute sealType : String;
        attribute maxPressure : PressureValue;
        attribute leakageRate : FlowRateValue;
        attribute coolingRequired : Boolean;

        port processFluidSide : HydraulicPort;
        port atmosphereSide : HydraulicPort;

        assert constraint sealIntegrity {
            processFluidSide.pressure <= maxPressure and
            leakageRate <= 0.001
        }
    }

    part def RadialBearing {
        attribute bearingType : String;
        attribute radialLoadCapacity : Real;
        attribute lubricationType : String;

        port loadPoint : MechanicalPort;
    }

    part def ThrustBearing {
        attribute axialLoadCapacity : Real;
        attribute lubricationType : String;

        port loadPoint : MechanicalPort;
    }

    part def PumpCasing {
        attribute material : String;
        attribute wallThickness : Real;
        attribute maxPressureRating : PressureValue;
        attribute maxTemperature : TemperatureValue;

        port suctionNozzle : HydraulicPort;
        port dischargeNozzle : HydraulicPort;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue;
        attribute ratedSpeed : RotationalSpeedValue;
        attribute voltage : Real;
        attribute frequency : Real;
        attribute motorEfficiency : EfficiencyValue;
        attribute powerFactor : Real;

        port electricalInput : ElectricalPort;
        port mechanicalOutput : MechanicalPort;

        assert constraint motorPerformance {
            mechanicalOutput.power == electricalInput.voltage * electricalInput.current * 
                powerFactor * motorEfficiency and
            mechanicalOutput.speed <= ratedSpeed
        }
    }

    part def VariableFrequencyDrive {
        attribute inputVoltage : Real;
        attribute outputFrequency : Real;
        attribute outputVoltage : Real;

        port powerInput : ElectricalPort;
        port motorOutput : ElectricalPort;

        perform action adjustSpeed {
            in targetSpeed : RotationalSpeedValue;
            out frequency : Real;
        }
    }

    part def PressureTransmitter {
        attribute range : PressureValue;
        attribute accuracy : Real;

        port processTap : HydraulicPort;
        attribute measuredPressure : PressureValue = processTap.pressure;
    }

    part def FlowTransmitter {
        attribute range : FlowRateValue;
        attribute accuracy : Real;

        port processTap : HydraulicPort;
        attribute measuredFlow : FlowRateValue = processTap.flowRate;
    }

    action def StartCommand;
    action def StopCommand;

    action def StartupSequence {
        in pump;
        out operatingSpeed : RotationalSpeedValue;

        first start;
        then action verifyAlignment {
            doc /* Verify shaft alignment and bearing condition */
        }
        then action primePump {
            doc /* Fill pump casing with liquid to prevent dry running */
        }
        then action openSuctionValve {
            doc /* Ensure suction valve is fully open */
        }
        then action startMotor {
            out speed = operatingSpeed;
        }
        then action graduallyOpenDischarge {
            doc /* Slowly open discharge valve to rated flow */
        }
        then action monitorPerformance {
            in currentFlow : FlowRateValue;
            in currentHead : HeadValue;
        }
        then done;
    }

    action def ShutdownSequence {
        in pump;

        first start;
        then action closeDischargeValve {
            doc /* Close discharge valve gradually */
        }
        then action stopMotor {
            doc /* De-energize motor */
        }
        then action closeSuctionValve {
            doc /* Close suction valve after motor stops */
        }
        then done;
    }

    action def MonitorPumpOperation {
        in suctionPressure : PressureValue;
        in dischargePressure : PressureValue;
        in flowRate : FlowRateValue;
        in motorPower : PowerValue;
        in fluidDensity : DensityValue;
        out head : HeadValue;
        out efficiency : EfficiencyValue;
        out npshAvailable : HeadValue;
    }

    state def PumpOperationalStates {
        entry; then stopped;

        state stopped {
            doc /* Pump is not running, all valves closed */
        }

        transition stopped_to_starting
            first stopped
            accept StartCommand
            then starting;

        state starting {
            doc /* Executing startup sequence */
        }

        transition starting_to_running
            first starting
            then running;

        state running {
            state normalOperation {
                doc /* Operating within design parameters */
            }

            state cavitating {
                doc /* NPSH available below required, cavitation occurring */
            }

            state runout {
                doc /* Flow exceeds maximum, potential damage */
            }

            transition normal_to_cavitation
                first normalOperation
                then cavitating;

            transition cavitation_to_normal
                first cavitating
                then normalOperation;

            transition normal_to_runout
                first normalOperation
                then runout;

            transition runout_to_normal
                first runout
                then normalOperation;
        }

        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;

        state stopping {
            doc /* Executing shutdown sequence */
        }

        transition stopping_to_stopped
            first stopping
            then stopped;
    }

    part def CentrifugalPump {
        doc /* Centrifugal pump design based on Igor Karassik principles:
             * converts rotational mechanical energy to hydrodynamic energy
             * through centrifugal force in a rotating impeller */

        attribute ratedFlowRate : FlowRateValue;
        attribute ratedHead : HeadValue;
        attribute ratedSpeed : RotationalSpeedValue;
        attribute npshRequired : HeadValue;
        attribute maxFlow : FlowRateValue;
        attribute shutoffHead : HeadValue;
        attribute overallEfficiency : EfficiencyValue;
        attribute specificSpeed : Real;
        attribute fluidDensity : DensityValue;

        port suction : HydraulicPort;
        port discharge : HydraulicPort;
        port powerSupply : ElectricalPort;

        part impeller : Impeller {
            attribute :>> diameter = 0.35;
            attribute :>> bladeCount = 6;
            attribute :>> bladeAngle = 25.0;
            attribute :>> hydraulicEfficiency = 0.87;
        }

        part volute : Volute {
            attribute :>> throatArea = 0.05;
            attribute :>> diffuserAngle = 8.0;
            attribute :>> pressureRecoveryFactor = 0.92;
        }

        part shaft : Shaft {
            attribute :>> diameter = 0.06;
            attribute :>> length = 1.2;
            attribute :>> material = "Stainless Steel 316";
            attribute :>> mechanicalEfficiency = 0.98;
        }

        part mechanicalSeal : MechanicalSeal {
            attribute :>> sealType = "Balanced Cartridge";
            attribute :>> maxPressure = 30.0;
            attribute :>> leakageRate = 0.0005;
            attribute :>> coolingRequired = true;
        }

        part radialBearings : RadialBearing[2] {
            attribute :>> bearingType = "Deep Groove Ball";
            attribute :>> radialLoadCapacity = 15000.0;
            attribute :>> lubricationType = "Oil Bath";
        }

        part thrustBearing : ThrustBearing {
            attribute :>> axialLoadCapacity = 8000.0;
            attribute :>> lubricationType = "Oil Bath";
        }

        part casing : PumpCasing {
            attribute :>> material = "Ductile Iron";
            attribute :>> wallThickness = 0.015;
            attribute :>> maxPressureRating = 35.0;
            attribute :>> maxTemperature = 150.0;
        }

        part motor : ElectricMotor {
            attribute :>> ratedPower = 22000.0;
            attribute :>> ratedSpeed = 1780.0;
            attribute :>> voltage = 480.0;
            attribute :>> frequency = 60.0;
            attribute :>> motorEfficiency = 0.94;
            attribute :>> powerFactor = 0.88;
        }

        part vfd : VariableFrequencyDrive {
            attribute :>> inputVoltage = 480.0;
            attribute :>> outputFrequency = 60.0;
            attribute :>> outputVoltage = 480.0;
        }

        part suctionPressureSensor : PressureTransmitter {
            attribute :>> range = 5.0;
            attribute :>> accuracy = 0.25;
        }

        part dischargePressureSensor : PressureTransmitter {
            attribute :>> range = 30.0;
            attribute :>> accuracy = 0.25;
        }

        part flowSensor : FlowTransmitter {
            attribute :>> range = 600.0;
            attribute :>> accuracy = 0.5;
        }

        connection suctionPath connect suction to casing.suctionNozzle;
        connection casingToImpeller connect casing.suctionNozzle to impeller.fluidInlet;
        connection impellerToVolute connect impeller.fluidOutlet to volute.inlet;
        connection voluteToDischarge connect volute.outlet to casing.dischargeNozzle;
        connection dischargePath connect casing.dischargeNozzle to discharge;

        connection powerToVFD connect powerSupply to vfd.powerInput;
        connection vfdToMotor connect vfd.motorOutput to motor.electricalInput;
        connection motorToShaft connect motor.mechanicalOutput to shaft.driverEnd;
        connection shaftToImpeller connect shaft.impellerEnd to impeller.shaftInput;

        connection suctionSensor connect suctionPressureSensor.processTap to suction;
        connection dischargeSensor connect dischargePressureSensor.processTap to discharge;
        connection flowMeasurement connect flowSensor.processTap to discharge;

        perform action pumpingOperation : MonitorPumpOperation {
            in suctionPressure = suctionPressureSensor.measuredPressure;
            in dischargePressure = dischargePressureSensor.measuredPressure;
            in flowRate = flowSensor.measuredFlow;
            in motorPower = motor.mechanicalOutput.power;
            in fluidDensity;
            out head;
            out efficiency;
            out npshAvailable;
        }

        state operationalState : PumpOperationalStates;

        assert constraint performanceCurve {
            discharge.flowRate <= maxFlow and
            (dischargePressureSensor.measuredPressure - suctionPressureSensor.measuredPressure) <= 
                shutoffHead * fluidDensity * 9.81
        }

        assert constraint npshAdequacy {
            pumpingOperation.npshAvailable >= npshRequired + 0.6
        }

        assert constraint efficiencyTarget {
            pumpingOperation.efficiency >= 0.72
        }
    }

    requirement <'REQ-KP-001'> primaryPumpingFunction {
        doc /* The centrifugal pump system shall transfer liquid from a low-pressure
             * suction source to a high-pressure discharge point by converting rotational
             * mechanical energy into fluid kinetic energy and then into pressure energy,
             * following Karassik centrifugal pump design principles. */
        
        subject pump : CentrifugalPump;

        require constraint flowCapability {
            pump.discharge.flowRate >= pump.ratedFlowRate * 0.90 and
            pump.discharge.flowRate <= pump.ratedFlowRate * 1.10
        }

        require constraint headGeneration {
            (pump.dischargePressureSensor.measuredPressure - 
             pump.suctionPressureSensor.measuredPressure) >= 
                pump.ratedHead * pump.fluidDensity * 9.81 * 0.95
        }
    }

    requirement <'REQ-KP-002'> hydraulicPerformance {
        doc /* The pump shall achieve specified hydraulic performance with
             * minimum energy losses through optimized impeller and volute design. */
        
        subject pump : CentrifugalPump;

        require constraint minimumEfficiency {
            pump.pumpingOperation.efficiency >= 0.72
        }

        require constraint impellerDesign {
            pump.impeller.hydraulicEfficiency >= 0.85 and
            pump.impeller.bladeCount >= 5 and
            pump.impeller.bladeCount <= 7
        }
    }

    requirement <'REQ-KP-003'> cavitationAvoidance {
        doc /* The pump shall operate without cavitation by maintaining adequate
             * net positive suction head available above the required NPSH. */
        
        subject pump : CentrifugalPump;

        require constraint npshMargin {
            pump.pumpingOperation.npshAvailable >= pump.npshRequired + 0.6
        }
    }

    requirement <'REQ-KP-004'> mechanicalReliability {
        doc /* The pump shall provide reliable continuous operation through
             * proper shaft support, sealing, and bearing systems. */
        
        subject pump : CentrifugalPump;

        require constraint sealPerformance {
            pump.mechanicalSeal.leakageRate <= 0.001 and
            pump.mechanicalSeal.maxPressure >= 
                pump.dischargePressureSensor.measuredPressure * 1.2
        }

        require constraint bearingSupport {
            pump.radialBearings[1].radialLoadCapacity >= 10000.0 and
            pump.thrustBearing.axialLoadCapacity >= 5000.0
        }
    }

    requirement <'REQ-KP-005'> operationalControl {
        doc /* The pump system shall provide controlled startup, shutdown,
             * and speed variation capabilities for process optimization. */
        
        subject pump : CentrifugalPump;

        require constraint speedControl {
            pump.vfd.outputFrequency >= 30.0 and
            pump.vfd.outputFrequency <= 70.0
        }
    }

    part karassikPumpingSystem : CentrifugalPump {
        attribute :>> ratedFlowRate = 450.0;
        attribute :>> ratedHead = 85.0;
        attribute :>> ratedSpeed = 1780.0;
        attribute :>> npshRequired = 4.2;
        attribute :>> maxFlow = 540.0;
        attribute :>> shutoffHead = 95.0;
        attribute :>> overallEfficiency = 0.78;
        attribute :>> specificSpeed = 42.5;
        attribute :>> fluidDensity = 998.0;
    }

    satisfy primaryPumpingFunction by karassikPumpingSystem;
    satisfy hydraulicPerformance by karassikPumpingSystem;
    satisfy cavitationAvoidance by karassikPumpingSystem;
    satisfy mechanicalReliability by karassikPumpingSystem;
    satisfy operationalControl by karassikPumpingSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import KarassikCentrifugalPumpSystem::*;

    part testSubject : Impeller {
        exhibit state sm : PumpOperationalStates;
    }

    action orchestrator {
        attribute testStartCommand : StartCommand;
        attribute testStopCommand : StopCommand;
        action triggerStartCommand send testStartCommand to testSubject;
        action triggerStopCommand send testStopCommand to testSubject;
        first triggerStartCommand;
        then triggerStopCommand;
    }
}

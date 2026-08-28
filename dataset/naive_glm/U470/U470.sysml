package IndustrialAxialPumpSubsystem {

    doc /* Complete industrial axial-flow pumping subsystem model. */;

    package ValueTypes {
        value type PressureValue :> Real {
            attribute unit : String = "Pa";
        }
        value type VolumeFlowRateValue :> Real {
            attribute unit : String = "m^3/s";
        }
        value type TemperatureValue :> Real {
            attribute unit : String = "degC";
        }
        value type RotationalSpeedValue :> Real {
            attribute unit : String = "rpm";
        }
        value type TorqueValue :> Real {
            attribute unit : String = "N*m";
        }
        value type PowerValue :> Real {
            attribute unit : String = "W";
        }
        value type VoltageValue :> Real {
            attribute unit : String = "V";
        }
        value type CurrentValue :> Real {
            attribute unit : String = "A";
        }
        value type FrequencyValue :> Real {
            attribute unit : String = "Hz";
        }
        value type LengthValue :> Real {
            attribute unit : String = "m";
        }
        value type DiameterValue :> Real {
            attribute unit : String = "m";
        }
        value type MassValue :> Real {
            attribute unit : String = "kg";
        }
        value type EfficiencyValue :> Real {
            attribute unit : String = "percent";
        }
        value type VibrationValue :> Real {
            attribute unit : String = "mm/s";
        }
        value type DurationValue :> Real {
            attribute unit : String = "s";
        }
    }

    package Items {
        item def Water {
            attribute density : Real = 1000.0;
            attribute densityUnit : String = "kg/m^3";
            attribute viscosity : Real = 0.001;
            attribute viscosityUnit : String = "Pa*s";
        }
        item def ElectricalPower;
        item def MechanicalPower;
        item def ControlSignal {
            attribute command : String;
            attribute priority : Integer = 0;
        }
        item def MeasurementSignal {
            attribute tag : String;
            attribute value : Real;
            attribute unit : String;
            attribute quality : String = "good";
            attribute timestamp : Real;
        }
        item def AlarmSignal {
            attribute severity : String;
            attribute code : String;
            attribute message : String;
        }
    }

    package Events {
        occurrence def StartCommand;
        occurrence def StopCommand;
        occurrence def SpeedReached;
        occurrence def StartFailure;
        occurrence def OverTemperature;
        occurrence def LowFlow;
        occurrence def OverPressure;
        occurrence def HighVibration;
        occurrence def MotorStopped;
        occurrence def FaultReset;
    }

    package Ports {
        import ValueTypes::*;
        import Items::*;

        port def FluidPort {
            attribute pressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
            attribute temperature : TemperatureValue;
            item fluid : Water;
        }
        port def ElectricalPowerPort {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute frequency : FrequencyValue;
            attribute power : PowerValue;
            item electricalPower : ElectricalPower;
        }
        port def MechanicalPowerPort {
            attribute rotationalSpeed : RotationalSpeedValue;
            attribute torque : TorqueValue;
            attribute power : PowerValue;
            item mechanicalPower : MechanicalPower;
        }
        port def SignalOutputPort {
            out item measurement : MeasurementSignal;
        }
        port def SignalInputPort {
            in item control : ControlSignal;
        }
        port def AlarmOutputPort {
            out item alarm : AlarmSignal;
        }
    }

    package Connections {
        import Ports::*;

        connection def FluidConnection {
            end upstream : FluidPort;
            end downstream : FluidPort;
        }
        connection def ShaftConnection {
            end driver : MechanicalPowerPort;
            end driven : MechanicalPowerPort;
        }
        connection def ElectricalConnection {
            end source : ElectricalPowerPort;
            end load : ElectricalPowerPort;
        }
        connection def SignalConnection {
            end source : SignalOutputPort;
            end target : SignalInputPort;
        }
    }

    package Components {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Connections::*;

        part def Impeller {
            doc /* Propeller-like impeller with 4 to 12 blades that pushes fluid axially. */;
            attribute numberOfBlades : Integer = 7;
            attribute bladeMaterial : String = "stainless steel";
            attribute hubDiameter : DiameterValue = 0.08;
            attribute tipDiameter : DiameterValue = 0.35;
            attribute pitchAngle : Real = 25.0;
            attribute pitchAngleUnit : String = "deg";
            port shaftConnection : MechanicalPowerPort;
            constraint bladeCountConstraint {
                numberOfBlades >= 4 and numberOfBlades <= 12
            }
        }

        part def PumpShaft {
            doc /* Heavy-duty stainless steel shaft supporting the impeller. */;
            attribute material : String = "stainless steel";
            attribute diameter : DiameterValue = 0.06;
            attribute length : LengthValue = 1.2;
            attribute mass : MassValue = 25.0;
            attribute yieldStrength : PressureValue = 250000000.0;
            port driveEnd : MechanicalPowerPort;
            port impellerEnd : MechanicalPowerPort;
        }

        part def Bearing {
            doc /* Bearing supporting the pump shaft. */;
            attribute type : String;
            attribute loadRating : Real = 50000.0;
            attribute loadRatingUnit : String = "N";
            attribute lubrication : String = "grease";
            attribute ratedLife : Real = 50000.0;
            attribute ratedLifeUnit : String = "h";
        }

        part def MechanicalSeal {
            doc /* Mechanical seal preventing fluid leakage at the shaft exit. */;
            attribute type : String = "mechanical";
            attribute faceMaterial : String = "silicon carbide";
            attribute secondarySealing : String = "Viton";
            attribute maxPressure : PressureValue = 1000000.0;
            attribute maxTemperature : TemperatureValue = 120.0;
        }

        part def PumpCasing {
            doc /* Robust cast iron casing forming the fluid inlet and outlet. */;
            attribute material : String = "cast iron";
            attribute inletDiameter : DiameterValue = 0.4;
            attribute outletDiameter : DiameterValue = 0.35;
            attribute designPressure : PressureValue = 600000.0;
            attribute wallThickness : LengthValue = 0.015;
            port inlet : FluidPort;
            port outlet : FluidPort;
        }

        part def AxialFlowPump {
            doc /* Axial-flow pump using a propeller-like impeller to push fluid straight along the axis of the pump shaft. */;
            attribute manufacturer : String = "FlowTech Industries";
            attribute model : String = "AXP-400-1450";
            attribute nominalSpeed : RotationalSpeedValue = 1450.0;
            attribute nominalFlowRate : VolumeFlowRateValue = 1.5;
            attribute nominalHead : PressureValue = 150000.0;
            attribute efficiency : EfficiencyValue = 85.0;
            attribute impellerDiameter : DiameterValue = 0.35;
            port inlet : FluidPort;
            port outlet : FluidPort;
            port shaftInput : MechanicalPowerPort;

            part impeller : Impeller {
                attribute numberOfBlades : Integer = 7;
            }
            part shaft : PumpShaft;
            part driveEndBearing : Bearing {
                attribute type : String = "roller";
            }
            part impellerEndBearing : Bearing {
                attribute type : String = "sleeve";
            }
            part seal : MechanicalSeal;
            part casing : PumpCasing;

            connection : ShaftConnection connect shaftInput to shaft.driveEnd;
            connection : ShaftConnection connect shaft.impellerEnd to impeller.shaftConnection;
            connection : FluidConnection connect inlet to casing.inlet;
            connection : FluidConnection connect casing.outlet to outlet;

            action def pressurizeFluid {
                doc /* Increases fluid pressure and velocity by imparting axial momentum via the rotating impeller. */;
                in item influid : Water;
                out item outfluid : Water;
                attribute speed : RotationalSpeedValue;
                attribute torque : TorqueValue;
                attribute powerInput : PowerValue;
                attribute pressureRise : PressureValue;
            }
        }

        part def ElectricMotor {
            doc /* Electric motor that receives electrical power and converts it into rotational mechanical force. */;
            attribute manufacturer : String = "ElectroDrive Corp";
            attribute model : String = "IM-75-400";
            attribute ratedPower : PowerValue = 75000.0;
            attribute ratedSpeed : RotationalSpeedValue = 1450.0;
            attribute ratedVoltage : VoltageValue = 400.0;
            attribute ratedCurrent : CurrentValue = 130.0;
            attribute ratedFrequency : FrequencyValue = 50.0;
            attribute efficiency : EfficiencyValue = 93.0;
            attribute powerFactor : Real = 0.85;
            attribute protectionClass : String = "IP55";
            attribute coolingMethod : String = "TEFC";
            attribute insulationClass : String = "F";
            port powerInput : ElectricalPowerPort;
            port shaftOutput : MechanicalPowerPort;

            action def convertEnergy {
                doc /* Converts incoming electrical power into rotational mechanical power. */;
                in item electric : ElectricalPower;
                out item mechanical : MechanicalPower;
                attribute inputVoltage : VoltageValue;
                attribute inputCurrent : CurrentValue;
                attribute outputSpeed : RotationalSpeedValue;
                attribute outputTorque : TorqueValue;
            }
        }

        part def IsolationValve {
            doc /* Isolation valve for maintenance shutoff on suction and discharge sides. */;
            attribute type : String = "gate";
            attribute nominalSize : DiameterValue = 0.4;
            attribute pressureRating : PressureValue = 1600000.0;
            attribute bodyMaterial : String = "cast iron";
            attribute seatMaterial : String = "EPDM";
            attribute position : String = "open";
            attribute actuation : String = "manual";
            port inlet : FluidPort;
            port outlet : FluidPort;
        }

        part def CheckValve {
            doc /* Check valve that prevents backflow when the system is shut down. */;
            attribute type : String = "swing";
            attribute nominalSize : DiameterValue = 0.4;
            attribute pressureRating : PressureValue = 1600000.0;
            attribute bodyMaterial : String = "cast iron";
            attribute seatMaterial : String = "bronze";
            attribute crackingPressure : PressureValue = 5000.0;
            port inlet : FluidPort;
            port outlet : FluidPort;

            state def CheckValveState {
                entry; then closed;
                state closed {
                    entry action { /* Valve disc seated, flow blocked */ }
                }
                state open {
                    entry action { /* Valve disc lifted, flow permitted */ }
                }
                transition openCheckValve
                    first closed
                    accept when inlet.pressure > outlet.pressure + crackingPressure
                    then open;
                transition closeCheckValve
                    first open
                    accept when outlet.pressure >= inlet.pressure
                    then closed;
            }
            exhibit CheckValveState;
        }

        part def Piping {
            doc /* Pipe section for suction or discharge fluid transport. */;
            attribute nominalDiameter : DiameterValue;
            attribute length : LengthValue;
            attribute material : String = "carbon steel";
            attribute schedule : String = "Sch 40";
            attribute roughness : Real = 0.046;
            attribute roughnessUnit : String = "mm";
            attribute designPressure : PressureValue = 1600000.0;
            port inlet : FluidPort;
            port outlet : FluidPort;
        }

        part def FlowMeter {
            doc /* Flow meter on the suction side measuring volumetric flow of fluid being pumped. */;
            attribute type : String = "electromagnetic";
            attribute manufacturer : String = "FlowMeasure Inc";
            attribute model : String = "EMF-400";
            attribute nominalSize : DiameterValue = 0.4;
            attribute accuracy : Real = 0.5;
            attribute accuracyUnit : String = "percent";
            attribute rangeMin : VolumeFlowRateValue = 0.0;
            attribute rangeMax : VolumeFlowRateValue = 3.0;
            attribute outputSignal : String = "4-20 mA";
            port inlet : FluidPort;
            port outlet : FluidPort;
            port signalOut : SignalOutputPort;
        }

        part def PressureTransmitter {
            doc /* Pressure transmitter for monitoring suction or discharge pressure. */;
            attribute type : String = "piezoresistive";
            attribute manufacturer : String = "PressureTech";
            attribute model : String = "PT-500";
            attribute rangeMin : PressureValue = 0.0;
            attribute rangeMax : PressureValue;
            attribute accuracy : Real = 0.25;
            attribute accuracyUnit : String = "percent";
            attribute outputSignal : String = "4-20 mA";
            attribute processConnectionSize : DiameterValue = 0.015;
            port processConnection : FluidPort;
            port signalOut : SignalOutputPort;
        }

        part def TemperatureTransmitter {
            doc /* Temperature transmitter for monitoring fluid temperature. */;
            attribute type : String = "RTD Pt100";
            attribute manufacturer : String = "TempSense Ltd";
            attribute model : String = "TT-100";
            attribute rangeMin : TemperatureValue = -20.0;
            attribute rangeMax : TemperatureValue;
            attribute accuracy : Real = 0.2;
            attribute accuracyUnit : String = "degC";
            attribute outputSignal : String = "4-20 mA";
            attribute sensorElement : String = "Pt100 Class A";
            port processConnection : FluidPort;
            port signalOut : SignalOutputPort;
        }
    }

    package Behaviors {
        import ValueTypes::*;
        import Items::*;
        import Events::*;

        action def StartSequence {
            doc /* Ramp-up sequence to bring the pump from rest to nominal speed. */;
            attribute rampDuration : DurationValue = 10.0;
            attribute targetSpeed : RotationalSpeedValue = 1450.0;

            action energizeMotor {
                doc /* Apply electrical power to the motor. */;
                out item power : ElectricalPower;
            }
            action rampUpSpeed {
                doc /* Gradually increase motor speed to target. */;
                in item power : ElectricalPower;
                attribute currentSpeed : RotationalSpeedValue;
                attribute targetSpeed : RotationalSpeedValue = 1450.0;
            }
            action openDischargePath {
                doc /* Verify discharge path is open for flow. */;
            }
            action verifySpeed {
                doc /* Confirm motor has reached target speed. */;
                attribute measuredSpeed : RotationalSpeedValue;
                attribute targetSpeed : RotationalSpeedValue = 1450.0;
                attribute tolerance : RotationalSpeedValue = 50.0;
            }
            succession energizeMotor then rampUpSpeed;
            succession rampUpSpeed then openDischargePath;
            succession openDischargePath then verifySpeed;
        }

        action def StopSequence {
            doc /* Controlled shutdown sequence to safely stop the pump. */;
            attribute decelDuration : DurationValue = 15.0;

            action rampDownSpeed {
                doc /* Gradually reduce motor speed to zero. */;
                attribute targetSpeed : RotationalSpeedValue = 0.0;
                attribute currentSpeed : RotationalSpeedValue;
            }
            action verifyFlowStopped {
                doc /* Confirm fluid flow has ceased. */;
                attribute measuredFlow : VolumeFlowRateValue;
            }
            action deEnergizeMotor {
                doc /* Remove electrical power from the motor. */;
            }
            succession rampDownSpeed then verifyFlowStopped;
            succession verifyFlowStopped then deEnergizeMotor;
        }

        action def FaultResponse {
            doc /* Emergency response to detected fault conditions. */;
            action tripMotor {
                doc /* Immediately remove power from the motor. */;
            }
            action logFaultData {
                doc /* Record all instrument readings at time of fault. */;
                attribute timestamp : Real;
                attribute faultCode : String;
            }
            action raiseAlarm {
                doc /* Transmit alarm signal to control system. */;
                out item alarm : AlarmSignal;
                attribute severity : String = "high";
            }
            succession tripMotor then logFaultData;
            succession logFaultData then raiseAlarm;
        }

        state def PumpOperation {
            doc /* Operational state machine for the axial pump subsystem with off, starting, running, stopping, and fault states. */;
            entry; then off;

            state off {
                doc /* Motor de-energized, system in standby. */;
                entry action { /* Ensure motor is de-energized and valves are in standby position */ }
            }
            state starting {
                doc /* Motor ramping up to nominal speed. */;
                entry action { /* Execute StartSequence: energize motor, ramp up speed */ }
                do action { /* Monitor speed ramp-up, suction pressure, and discharge pressure */ }
                exit action { /* Confirm speed reached nominal value, log successful start */ }
            }
            state running {
                doc /* Normal continuous operation at nominal speed. */;
                entry action { /* Enter normal operation mode, enable continuous monitoring */ }
                do action { /* Continuously monitor flow rate, pressures, temperatures, vibration */ }
                exit action { /* Log operating data snapshot before transition */ }
            }
            state stopping {
                doc /* Controlled shutdown in progress. */;
                entry action { /* Execute StopSequence: ramp down speed */ }
                do action { /* Monitor deceleration and flow reduction */ }
                exit action { /* Confirm motor stopped, de-energize motor */ }
            }
            state fault {
                doc /* Fault condition detected, system in safe state. */;
                entry action { /* Execute FaultResponse: trip motor, log data, raise alarm */ }
                do action { /* Maintain safe condition, await fault reset */ }
                exit action { /* Clear fault indicators, prepare for restart */ }
            }

            transition off_to_starting
                first off
                accept StartCommand
                then starting;
            transition starting_to_running
                first starting
                accept SpeedReached
                then running;
            transition starting_to_fault
                first starting
                accept StartFailure
                then fault;
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            transition running_to_fault_overtemp
                first running
                accept OverTemperature
                then fault;
            transition running_to_fault_lowflow
                first running
                accept LowFlow
                then fault;
            transition running_to_fault_overpressure
                first running
                accept OverPressure
                then fault;
            transition running_to_fault_vibration
                first running
                accept HighVibration
                then fault;
            transition stopping_to_off
                first stopping
                accept MotorStopped
                then off;
            transition stopping_to_fault
                first stopping
                accept OverTemperature
                then fault;
            transition fault_to_off
                first fault
                accept FaultReset
                then off;
        }
    }

    package Assembly {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Connections::*;
        import Components::*;
        import Behaviors::*;

        part def AxialPumpSubsystem {
            doc /* Packaged industrial axial-flow pumping subsystem with pump, motor, valves, piping, and instrumentation for high-flow-rate applications. */;
            attribute systemTag : String = "AXIAL-PUMP-SUBSYSTEM-001";
            attribute application : String = "industrial water circulation";
            attribute designFlowRate : VolumeFlowRateValue = 1.5;
            attribute designHead : PressureValue = 150000.0;
            attribute fluidType : String = "water";
            attribute installationType : String = "skid-mounted";

            port suctionConnection : FluidPort;
            port dischargeConnection : FluidPort;
            port powerInput : ElectricalPowerPort;
            port commandInput : SignalInputPort;

            part suctionPiping : Piping {
                attribute nominalDiameter : DiameterValue = 0.4;
                attribute length : LengthValue = 5.0;
            }
            part suctionIsolationValve : IsolationValve {
                attribute nominalSize : DiameterValue = 0.4;
                attribute position : String = "open";
            }
            part suctionFlowMeter : FlowMeter {
                attribute nominalSize : DiameterValue = 0.4;
            }
            part suctionPressureTransmitter : PressureTransmitter {
                attribute rangeMax : PressureValue = 300000.0;
            }
            part suctionTemperatureTransmitter : TemperatureTransmitter {
                attribute rangeMax : TemperatureValue = 80.0;
            }
            part pump : AxialFlowPump {
                attribute nominalFlowRate : VolumeFlowRateValue = 1.5;
                attribute nominalHead : PressureValue = 150000.0;
                attribute efficiency : EfficiencyValue = 85.0;
            }
            part motor : ElectricMotor {
                attribute ratedPower : PowerValue = 75000.0;
                attribute ratedVoltage : VoltageValue = 400.0;
                attribute ratedCurrent : CurrentValue = 130.0;
                attribute efficiency : EfficiencyValue = 93.0;
            }
            part dischargePressureTransmitter : PressureTransmitter {
                attribute rangeMax : PressureValue = 500000.0;
            }
            part dischargeTemperatureTransmitter : TemperatureTransmitter {
                attribute rangeMax : TemperatureValue = 80.0;
            }
            part checkValve : CheckValve {
                attribute nominalSize : DiameterValue = 0.4;
                attribute crackingPressure : PressureValue = 5000.0;
            }
            part dischargeIsolationValve : IsolationValve {
                attribute nominalSize : DiameterValue = 0.4;
                attribute position : String = "open";
            }
            part dischargePiping : Piping {
                attribute nominalDiameter : DiameterValue = 0.35;
                attribute length : LengthValue = 10.0;
            }

            connection : FluidConnection connect suctionConnection to suctionPiping.inlet;
            connection : FluidConnection connect suctionPiping.outlet to suctionIsolationValve.inlet;
            connection : FluidConnection connect suctionIsolationValve.outlet to suctionFlowMeter.inlet;
            connection : FluidConnection connect suctionFlowMeter.outlet to pump.inlet;
            connection : FluidConnection connect pump.outlet to checkValve.inlet;
            connection : FluidConnection connect checkValve.outlet to dischargeIsolationValve.inlet;
            connection : FluidConnection connect dischargeIsolationValve.outlet to dischargePiping.inlet;
            connection : FluidConnection connect dischargePiping.outlet to dischargeConnection;

            connection : ShaftConnection connect motor.shaftOutput to pump.shaftInput;
            connection : ElectricalConnection connect powerInput to motor.powerInput;

            connection : FluidConnection connect suctionFlowMeter.outlet to suctionPressureTransmitter.processConnection;
            connection : FluidConnection connect suctionFlowMeter.outlet to suctionTemperatureTransmitter.processConnection;
            connection : FluidConnection connect checkValve.inlet to dischargePressureTransmitter.processConnection;
            connection : FluidConnection connect checkValve.inlet to dischargeTemperatureTransmitter.processConnection;

            connection : SignalConnection connect commandInput to commandInput;

            exhibit PumpOperation;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Components::*;
        import Assembly::*;
        import Behaviors::*;

        requirement def PumpingCapacityRequirement {
            doc /* The axial pump subsystem shall deliver the design flow rate at the specified head for high-flow applications. */;
            subject subsystem : AxialPumpSubsystem;
            attribute minFlowRate : VolumeFlowRateValue = 1.0;
            attribute minHead : PressureValue = 100000.0;
            require subsystem.designFlowRate >= minFlowRate;
            require subsystem.designHead >= minHead;
        }

        requirement def ImpellerBladeCountRequirement {
            doc /* The axial flow pump impeller shall have between 4 and 12 propeller-like blades. */;
            subject impeller : Impeller;
            require impeller.numberOfBlades >= 4;
            require impeller.numberOfBlades <= 12;
        }

        requirement def MotorSpeedRequirement {
            doc /* The electric motor shall drive the pump shaft at the nominal rotational speed of 1450 RPM. */;
            subject motor : ElectricMotor;
            attribute nominalSpeed : RotationalSpeedValue = 1450.0;
            require motor.ratedSpeed == nominalSpeed;
        }

        requirement def ShaftMaterialRequirement {
            doc /* The pump shaft shall be made of heavy-duty stainless steel. */;
            subject shaft : PumpShaft;
            require shaft.material == "stainless steel";
        }

        requirement def BearingSupportRequirement {
            doc /* The pump shaft shall be supported by bearings at both the drive end and the impeller end. */;
            subject pump : AxialFlowPump;
            require pump.driveEndBearing.type != "";
            require pump.impellerEndBearing.type != "";
        }

        requirement def SealRequirement {
            doc /* A mechanical seal shall prevent fluid from leaking where the shaft exits the pump housing. */;
            subject seal : MechanicalSeal;
            require seal.type == "mechanical";
        }

        requirement def CasingMaterialRequirement {
            doc /* The pump casing shall be made of robust cast iron forming the fluid inlet and outlet. */;
            subject casing : PumpCasing;
            require casing.material == "cast iron";
        }

        requirement def BackflowPreventionRequirement {
            doc /* A check valve on the discharge side shall prevent backflow when the system is shut down. */;
            subject checkValve : CheckValve;
            require checkValve.type == "swing";
        }

        requirement def IsolationValveRequirement {
            doc /* Isolation valves shall be provided on both suction and discharge sides for maintenance. */;
            subject subsystem : AxialPumpSubsystem;
            require subsystem.suctionIsolationValve.type == "gate";
            require subsystem.dischargeIsolationValve.type == "gate";
        }

        requirement def InstrumentationRequirement {
            doc /* The subsystem shall include a flow meter on the suction side and pressure and temperature transmitters on both suction and discharge sides. */;
            subject subsystem : AxialPumpSubsystem;
            require subsystem.suctionFlowMeter.type == "electromagnetic";
            require subsystem.suctionPressureTransmitter.type == "piezoresistive";
            require subsystem.suctionTemperatureTransmitter.type == "RTD Pt100";
            require subsystem.dischargePressureTransmitter.type == "piezoresistive";
            require subsystem.dischargeTemperatureTransmitter.type == "RTD Pt100";
        }

        requirement def OperationalStatesRequirement {
            doc /* The subsystem shall implement five operational states: off, starting, running, stopping, and fault. The system shall transition from off to starting on a start command, from starting to running when speed is reached, from running to stopping on a stop command, from stopping to off when the motor stops, and to fault from any operating state on detection of a fault condition. */;
            subject operation : PumpOperation;
        }

        requirement def ContinuousOperationRequirement {
            doc /* The subsystem shall be designed for reliable continuous use in applications requiring high flow rates such as irrigation, drainage, or industrial water circulation. */;
            subject subsystem : AxialPumpSubsystem;
            attribute minMTBF : Real = 8000.0;
            attribute minMTBFUnit : String = "h";
            require subsystem.application == "industrial water circulation";
        }

        requirement def ElectricalPowerConversionRequirement {
            doc /* The electric motor shall receive electrical power and convert it into rotational mechanical force to spin the impeller. */;
            subject motor : ElectricMotor;
            require motor.ratedPower > 0;
            require motor.ratedSpeed > 0;
        }

        requirement def FluidPathRequirement {
            doc /* Fluid shall enter through suction piping, pass through a suction isolation valve, enter the pump where its pressure and velocity are increased, exit through a check valve and discharge isolation valve, and flow into discharge piping towards its destination. */;
            subject subsystem : AxialPumpSubsystem;
        }

        requirement def AxialFlowDesignRequirement {
            doc /* The pump shall use a propeller-like impeller to push fluid straight along the axis of the pump shaft, similar to a boat propeller in a tube. */;
            subject pump : AxialFlowPump;
            require pump.impellerDiameter > 0;
        }
    }
}

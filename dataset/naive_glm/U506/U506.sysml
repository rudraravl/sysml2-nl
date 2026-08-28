package GasolinePumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value types with units
    value def PressureValue :> Real {
        unit 'Pa';
    }
    
    value def FlowRateValue :> Real {
        unit 'L/min';
    }
    
    value def TemperatureValue :> Real {
        unit 'degC';
    }
    
    value def VibrationValue :> Real {
        unit 'mm/s';
    }
    
    value def VoltageValue :> Real {
        unit 'V';
    }
    
    value def CurrentValue :> Real {
        unit 'A';
    }
    
    // Item definitions
    item def Gasoline {
        attribute density : Real = 0.74 [g/cm3];
        attribute flashPoint : Real = -43 [degC];
    }
    
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    // Port definitions
    port def FluidPort {
        out item gasoline : Gasoline;
        ref attribute pressure : PressureValue;
    }
    
    port def ElectricalPort {
        in item power : ElectricalPower;
    }
    
    port def ControlPort {
        in attribute startCommand : Boolean;
        in attribute stopCommand : Boolean;
        out attribute status : String;
        out attribute alarm : Boolean;
    }
    
    port def SensorSignalPort {
        out attribute measuredValue : Real;
    }
    
    // Sensor definitions
    part def PressureSensor {
        port measuredOut : SensorSignalPort;
        attribute pressureReading : PressureValue;
        private attribute calibrationFactor : Real = 1.0;
        
        action def measurePressure {
            in fluidPressure : PressureValue;
            out reading : PressureValue;
        }
    }
    
    part def FlowSensor {
        port measuredOut : SensorSignalPort;
        attribute flowReading : FlowRateValue;
        
        action def measureFlow {
            in fluidFlow : FlowRateValue;
            out reading : FlowRateValue;
        }
    }
    
    part def TemperatureSensor {
        port measuredOut : SensorSignalPort;
        attribute temperatureReading : TemperatureValue;
        
        action def measureTemperature {
            in targetTemp : TemperatureValue;
            out reading : TemperatureValue;
        }
    }
    
    part def VibrationSensor {
        port measuredOut : SensorSignalPort;
        attribute vibrationReading : VibrationValue;
        
        action def measureVibration {
            in targetVibration : VibrationValue;
            out reading : VibrationValue;
        }
    }
    
    // Electric Motor
    part def ElectricMotor {
        port powerIn : ElectricalPort;
        port shaftOut : ~TorquePort;
        port tempSensorMount : ~SensorMountPort;
        port vibSensorMount : ~SensorMountPort;
        
        attribute operatingTemperature : TemperatureValue;
        attribute vibrationLevel : VibrationValue;
        attribute maxTemperature : TemperatureValue = 90 [degC];
        attribute maxVibration : VibrationValue = 4.5 [mm/s];
        attribute isOverheating : Boolean;
        attribute isVibratingExcessively : Boolean;
        
        action def driveShaft {
            in power : ElectricalPower;
            out torque : Real;
        }
    }
    
    port def TorquePort {
        out attribute torque : Real;
        out attribute rotationalSpeed : Real;
    }
    
    port def SensorMountPort {
        in attribute physicalQuantity : Real;
    }
    
    // Impeller
    part def Impeller {
        port shaftIn : ~TorquePort;
        port fluidOut : FluidPort;
        port fluidIn : FluidPort;
        attribute rotationalSpeed : Real;
        attribute generatedPressure : PressureValue;
        
        action def generatePressure {
            in torque : Real;
            in inletGasoline : Gasoline;
            out pressurizedGasoline : Gasoline;
            out dischargePressure : PressureValue;
        }
    }
    
    // Sealed Casing
    part def SealedCasing {
        port inlet : FluidPort;
        port discharge : FluidPort;
        port inletPressureSensorMount : ~SensorMountPort;
        port dischargePressureSensorMount : ~SensorMountPort;
        port flowSensorMount : ~SensorMountPort;
        
        attribute sealIntegrity : Boolean = true;
        attribute maxOperatingPressure : PressureValue = 500000 [Pa];
        
        action def containFluid {
            in incomingGasoline : Gasoline;
            out outgoingGasoline : Gasoline;
        }
    }
    
    // Gasoline Pump Assembly
    part def GasolinePump {
        port fluidInlet : FluidPort;
        port fluidDischarge : FluidPort;
        port electricalInput : ElectricalPort;
        port controlInterface : ControlPort;
        
        part motor : ElectricMotor;
        part impeller : Impeller;
        part casing : SealedCasing;
        
        part inletPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part flowRateSensor : FlowSensor;
        part motorTempSensor : TemperatureSensor;
        part motorVibrationSensor : VibrationSensor;
        
        attribute inletPressure : PressureValue;
        attribute dischargePressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute motorTemperature : TemperatureValue;
        attribute motorVibration : VibrationValue;
        attribute minPrimingPressure : PressureValue = 50000 [Pa];
        attribute currentState : String;
        attribute alarmActive : Boolean = false;
        
        // Connections
        connect electricalInput to motor.powerIn;
        connect motor.shaftOut to impeller.shaftIn;
        connect fluidInlet to casing.inlet;
        connect casing.discharge to fluidDischarge;
        connect casing.inlet to impeller.fluidIn;
        connect impeller.fluidOut to casing.discharge;
        
        connect casing.inletPressureSensorMount to inletPressureSensor.measuredOut;
        connect casing.dischargePressureSensorMount to dischargePressureSensor.measuredOut;
        connect casing.flowSensorMount to flowRateSensor.measuredOut;
        connect motor.tempSensorMount to motorTempSensor.measuredOut;
        connect motor.vibSensorMount to motorVibrationSensor.measuredOut;
        
        state def PumpStateMachine {
            entry; then stopped;
            
            state stopped {
                entry action {
                    currentState = "stopped";
                    alarmActive = false;
                }
            }
            
            state priming {
                entry action {
                    currentState = "priming";
                }
                
                do action verifyPriming {
                    // Check inlet pressure is sufficient
                    if inletPressure >= minPrimingPressure {
                        // Priming successful
                    } else {
                        // Priming failed
                    }
                }
            }
            
            state running {
                entry action {
                    currentState = "running";
                }
                
                do action pumpFuel {
                    // Actively pumping fuel
                }
            }
            
            state faulted {
                entry action {
                    currentState = "faulted";
                    alarmActive = true;
                }
                
                do action raiseAlarm {
                    // Raise alarm notification
                }
            }
            
            transition stopped_to_priming
                first stopped 
                then priming 
                when controlInterface.startCommand == true;
            
            transition priming_to_running
                first priming 
                then running 
                when inletPressure >= minPrimingPressure 
                accept verifyPriming;
            
            transition priming_to_faulted
                first priming 
                then faulted 
                when inletPressure < minPrimingPressure 
                accept verifyPriming;
            
            transition running_to_faulted_overtemp
                first running 
                then faulted 
                when motorTemperature > motor.maxTemperature;
            
            transition running_to_faulted_vibration
                first running 
                then faulted 
                when motorVibration > motor.maxVibration;
            
            transition running_to_faulted_seal
                first running 
                then faulted 
                when casing.sealIntegrity == false;
            
            transition faulted_to_stopped
                first faulted 
                then stopped 
                when controlInterface.stopCommand == true;
            
            transition running_to_stopped
                first running 
                then stopped 
                when controlInterface.stopCommand == true;
        }
        
        exhibit PumpStateMachine;
    }
    
    // Supply Tank
    part def SupplyTank {
        port outlet : FluidPort;
        attribute capacity : Real = 5000 [L];
        attribute currentLevel : Real;
        attribute storedGasoline : Gasoline;
        
        action def supplyGasoline {
            out gasoline : Gasoline;
        }
    }
    
    // Receiving Vessel
    part def ReceivingVessel {
        port inlet : FluidPort;
        attribute capacity : Real = 10000 [L];
        attribute currentLevel : Real;
        attribute receivedGasoline : Gasoline;
        
        action def receiveGasoline {
            in gasoline : Gasoline;
        }
    }
    
    // Piping
    part def Pipe {
        port endA : FluidPort;
        port endB : FluidPort;
        attribute length : Real;
        attribute diameter : Real;
        attribute material : String = "stainless steel";
        
        action def transportFluid {
            in gasoline : Gasoline;
            out gasoline : Gasoline;
        }
    }
    
    // Control System
    part def ControlSystem {
        port pumpControl : ControlPort;
        attribute systemStatus : String;
        attribute commandQueue : String[*];
        
        action def sendStartCommand {
            out startCmd : Boolean = true;
        }
        
        action def sendStopCommand {
            out stopCmd : Boolean = true;
        }
        
        action def monitorStatus {
            in status : String;
            in alarm : Boolean;
        }
    }
    
    // Electrical Supply
    part def ElectricalSupply {
        port powerOutput : ElectricalPort;
        attribute outputVoltage : VoltageValue = 480 [V];
        attribute outputCurrent : CurrentValue = 50 [A];
        attribute isEnergized : Boolean = true;
        
        action def supplyPower {
            out power : ElectricalPower;
        }
    }
    
    // Complete Subsystem Assembly
    part GasolinePumpingSubsystemAssembly {
        part supplyTank : SupplyTank {
            attribute currentLevel : Real = 4000 [L];
        }
        
        part receivingVessel : ReceivingVessel {
            attribute currentLevel : Real = 0 [L];
        }
        
        part pump : GasolinePump;
        
        part suctionPipe : Pipe {
            attribute length : Real = 2.0 [m];
            attribute diameter : Real = 0.075 [m];
        }
        
        part dischargePipe : Pipe {
            attribute length : Real = 5.0 [m];
            attribute diameter : Real = 0.065 [m];
        }
        
        part controlSystem : ControlSystem;
        part electricalSupply : ElectricalSupply;
        
        // Connect supply tank to pump via suction pipe
        connect supplyTank.outlet to suctionPipe.endA;
        connect suctionPipe.endB to pump.fluidInlet;
        
        // Connect pump to receiving vessel via discharge pipe
        connect pump.fluidDischarge to dischargePipe.endA;
        connect dischargePipe.endB to receivingVessel.inlet;
        
        // Connect electrical supply to pump
        connect electricalSupply.powerOutput to pump.electricalInput;
        
        // Connect control system to pump
        connect controlSystem.pumpControl to pump.controlInterface;
    }
    
    // Requirements
    requirement def PumpSafetyRequirements {
        subject pump : GasolinePump;
        
        requirement PumpShallStartOnCommand {
            subject pump : GasolinePump;
            doc /* The pump shall transition from stopped to priming state upon receiving a start command from the control system. */
            require pump.controlInterface.startCommand == true implies pump.currentState == "priming" or pump.currentState == "running";
        }
        
        requirement PumpShallStopOnCommand {
            subject pump : GasolinePump;
            doc /* The pump shall transition to stopped state upon receiving a stop command from the control system. */
            require pump.controlInterface.stopCommand == true implies pump.currentState == "stopped";
        }
        
        requirement PumpShallVerifyPriming {
            subject pump : GasolinePump;
            doc /* The pump shall verify sufficient inlet pressure before transitioning to running state. */
            require pump.inletPressure >= pump.minPrimingPressure;
        }
        
        requirement PumpShallFaultOnOverheating {
            subject pump : GasolinePump;
            doc /* The pump shall enter faulted state and raise an alarm if motor temperature exceeds maximum. */
            require pump.motorTemperature > pump.motor.maxTemperature implies pump.currentState == "faulted" and pump.alarmActive == true;
        }
        
        requirement PumpShallFaultOnExcessiveVibration {
            subject pump : GasolinePump;
            doc /* The pump shall enter faulted state and raise an alarm if motor vibration exceeds maximum. */
            require pump.motorVibration > pump.motor.maxVibration implies pump.currentState == "faulted" and pump.alarmActive == true;
        }
        
        requirement PumpShallFaultOnSealFailure {
            subject pump : GasolinePump;
            doc /* The pump shall enter faulted state and raise an alarm if casing seal integrity is compromised. */
            require pump.casing.sealIntegrity == false implies pump.currentState == "faulted" and pump.alarmActive == true;
        }
        
        requirement PumpShallMonitorInletPressure {
            subject pump : GasolinePump;
            doc /* The pump shall continuously monitor inlet pressure via inlet pressure sensor. */
            require pump.inletPressureSensor.pressureReading == pump.inletPressure;
        }
        
        requirement PumpShallMonitorDischargePressure {
            subject pump : GasolinePump;
            doc /* The pump shall continuously monitor discharge pressure via discharge pressure sensor. */
            require pump.dischargePressureSensor.pressureReading == pump.dischargePressure;
        }
        
        requirement PumpShallMonitorFlowRate {
            subject pump : GasolinePump;
            doc /* The pump shall continuously monitor gasoline flow rate via flow rate sensor. */
            require pump.flowRateSensor.flowReading == pump.flowRate;
        }
        
        requirement PumpShallMonitorMotorTemperature {
            subject pump : GasolinePump;
            doc /* The pump shall continuously monitor motor temperature via temperature sensor. */
            require pump.motorTempSensor.temperatureReading == pump.motorTemperature;
        }
        
        requirement PumpShallMonitorMotorVibration {
            subject pump : GasolinePump;
            doc /* The pump shall continuously monitor motor vibration via vibration sensor. */
            require pump.motorVibrationSensor.vibrationReading == pump.motorVibration;
        }
    }
    
    requirement def SubsystemIntegrationRequirements {
        subject subsystem : GasolinePumpingSubsystemAssembly;
        
        requirement SupplyTankShallConnectToPump {
            subject subsystem : GasolinePumpingSubsystemAssembly;
            doc /* The supply tank shall be connected to the pump inlet via suction piping. */
            require subsystem.supplyTank.outlet.connectedTo == subsystem.pump.fluidInlet;
        }
        
        requirement PumpShallConnectToReceivingVessel {
            subject subsystem : GasolinePumpingSubsystemAssembly;
            doc /* The pump discharge shall be connected to the receiving vessel via discharge piping. */
            require subsystem.pump.fluidDischarge.connectedTo == subsystem.receivingVessel.inlet;
        }
        
        requirement ElectricalSupplyShallPowerPump {
            subject subsystem : GasolinePumpingSubsystemAssembly;
            doc /* The electrical supply shall provide high-voltage power to the pump motor. */
            require subsystem.electricalSupply.outputVoltage >= 400 [V];
        }
        
        requirement ControlSystemShallManagePump {
            subject subsystem : GasolinePumpingSubsystemAssembly;
            doc /* The control system shall send start/stop commands and monitor pump status. */
            require subsystem.controlSystem.pumpControl.connectedTo == subsystem.pump.controlInterface;
        }
    }
    
    // Verification actions
    verification verifyPumpStartCommand {
        subject pump : GasolinePump;
        objective verify PumpSafetyRequirements::PumpShallStartOnCommand;
        method action {
            // Simulate start command and verify state transition
        }
    }
    
    verification verifyPumpStopCommand {
        subject pump : GasolinePump;
        objective verify PumpSafetyRequirements::PumpShallStopOnCommand;
        method action {
            // Simulate stop command and verify state transition
        }
    }
    
    verification verifyOverheatingProtection {
        subject pump : GasolinePump;
        objective verify PumpSafetyRequirements::PumpShallFaultOnOverheating;
        method action {
            // Simulate overheating condition and verify faulted state
        }
    }
    
    verification verifySealFailureProtection {
        subject pump : GasolinePump;
        objective verify PumpSafetyRequirements::PumpShallFaultOnSealFailure;
        method action {
            // Simulate seal failure and verify faulted state
        }
    }
}

package 'Condensate Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def VolumeValue {
            attribute num : Real;
        }
        
        attribute def PressureValue {
            attribute num : Real;
        }
        
        attribute def FlowRateValue {
            attribute num : Real;
        }
        
        attribute def PowerValue {
            attribute num : Real;
        }
        
        attribute def TemperatureValue {
            attribute num : Real;
        }
        
        enum def PumpOperatingState {
            enum stopped;
            enum starting;
            enum running;
            enum stopping;
            enum faulted;
        }
        
        item def Condensate {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute volume : VolumeValue;
        }
        
        port def FluidInletPort {
            attribute inletPressure : PressureValue;
            attribute inletTemperature : TemperatureValue;
            in item condensateIn : Condensate;
        }
        
        port def FluidOutletPort {
            attribute outletPressure : PressureValue;
            attribute outletTemperature : TemperatureValue;
            out item condensateOut : Condensate;
        }
        
        port def PowerSupplyPort {
            attribute voltage : Real;
            attribute current : Real;
            attribute powerDrawn : PowerValue;
        }
        
        port def ControlPort {
            in attribute startSignal : ScalarValues::Boolean;
            in attribute stopSignal : ScalarValues::Boolean;
            out attribute statusSignal : PumpOperatingState;
            out attribute alarmSignal : ScalarValues::Boolean;
        }
        
        part def CondensateReceiver {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute highLevelSetpoint : VolumeValue;
            attribute lowLevelSetpoint : VolumeValue;
            
            port outletPort : FluidOutletPort;
            
            assert constraint levelLimits {
                currentLevel.num >= 0.0 & currentLevel.num <= capacity.num
            }
        }
        
        part def CondensatePump {
            attribute ratedFlowRate : FlowRateValue;
            attribute ratedDischargeHead : PressureValue;
            attribute ratedPower : PowerValue;
            attribute motorEfficiency : Real;
            attribute pumpEfficiency : Real;
            attribute currentOperatingState : PumpOperatingState default PumpOperatingState::stopped;
            
            port suctionPort : FluidInletPort;
            port dischargePort : FluidOutletPort;
            port powerPort : PowerSupplyPort;
            port controlPort : ControlPort;
            
            perform action pumpingAction : PumpCondensateAction {
                in condensateIn = suctionPort.condensateIn;
                out condensateOut = dischargePort.condensateOut;
            }
            
            state pumpController {
                entry; then idle;
                
                state idle;
                
                transition idleToStarting
                    first idle
                    accept startCmd : ScalarValues::Boolean
                    if startCmd
                    then starting;
                
                state starting;
                
                transition startingToRunning
                    first starting
                    then running;
                
                state running;
                
                transition runningToStopping
                    first running
                    accept stopCmd : ScalarValues::Boolean
                    if stopCmd
                    then stopping;
                
                transition runningToFaulted
                    first running
                    accept faultCondition : ScalarValues::Boolean
                    if faultCondition
                    then faulted;
                
                state stopping;
                
                transition stoppingToIdle
                    first stopping
                    then idle;
                
                state faulted;
                
                transition faultedToIdle
                    first faulted
                    accept resetCmd : ScalarValues::Boolean
                    if resetCmd
                    then idle;
            }
        }
        
        part def DischargePiping {
            attribute nominalDiameter : Real;
            attribute pipeLength : Real;
            attribute pressureDrop : PressureValue;
            
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;
        }
        
        part def StorageTank {
            attribute storageCapacity : VolumeValue;
            attribute currentVolume : VolumeValue;
            attribute maxOperatingPressure : PressureValue;
            attribute maxOperatingTemperature : TemperatureValue;
            
            port inletPort : FluidInletPort;
            
            assert constraint volumeLimit {
                currentVolume.num <= storageCapacity.num
            }
            
            assert constraint pressureLimit {
                inletPort.inletPressure.num <= maxOperatingPressure.num
            }
            
            assert constraint temperatureLimit {
                inletPort.inletTemperature.num <= maxOperatingTemperature.num
            }
        }
        
        part def FlowTransmitter {
            attribute measuredFlowRate : FlowRateValue;
            attribute measurementAccuracy : Real;
            attribute calibrationFactor : Real;
            
            port measurementPort : FluidInletPort;
        }
        
        part def PressureTransmitter {
            attribute measuredPressure : PressureValue;
            attribute measurementAccuracy : Real;
            attribute calibrationFactor : Real;
            
            port measurementPort : FluidInletPort;
        }
        
        action def PumpCondensateAction {
            in condensateIn : Condensate;
            out condensateOut : Condensate;
            
            action calculateDischargePressure {
                in suctionPressure : PressureValue;
                in dischargeHead : PressureValue;
                out dischargePressure : PressureValue;
            }
            
            action transferFluid {
                in sourceFluid : Condensate;
                in flowRate : FlowRateValue;
                out deliveredFluid : Condensate;
            }
            
            first start;
            then calculateDischargePressure;
            then transferFluid;
            then done;
        }
        
        requirement def PumpFlowRequirement {
            doc /* The condensate pump shall deliver the minimum required flow rate at rated discharge head. */
            
            subject pump : CondensatePump;
            
            require constraint minimumFlowRate {
                pump.dischargePort.condensateOut.volume.num >= pump.ratedFlowRate.num * 0.95
            }
        }
        
        requirement def PumpPressureRequirement {
            doc /* The condensate pump shall develop the specified discharge head. */
            
            subject pump : CondensatePump;
            
            require constraint dischargeHeadRequirement {
                pump.dischargePort.outletPressure.num - pump.suctionPort.inletPressure.num >= pump.ratedDischargeHead.num * 0.90
            }
        }
        
        requirement def SystemContinuityRequirement {
            doc /* The pumping subsystem shall maintain continuous condensate transfer from receiver to storage. */
            
            subject subsystem : CondensatePumpingSubsystem;
            
            require constraint continuousTransfer {
                subsystem.pump.currentOperatingState == PumpOperatingState::running implies
                subsystem.flowTransmitter.measuredFlowRate.num > 0.0
            }
        }
        
        requirement def ReceiverLevelControlRequirement {
            doc /* The pump shall start when receiver level reaches high setpoint and stop at low setpoint. */
            
            subject receiver : CondensateReceiver;
            subject pump : CondensatePump;
            
            require constraint highLevelStart {
                receiver.currentLevel.num >= receiver.highLevelSetpoint.num implies
                pump.controlPort.startSignal
            }
            
            require constraint lowLevelStop {
                receiver.currentLevel.num <= receiver.lowLevelSetpoint.num implies
                pump.controlPort.stopSignal
            }
        }
    }
    
    package Usages {
        import Definitions::*;
        
        part condensatePumpingSubsystem : CondensatePumpingSubsystem {
            
            part receiver : CondensateReceiver {
                attribute :>> capacity : VolumeValue {
                    attribute :>> num = 1000.0;
                }
                attribute :>> highLevelSetpoint : VolumeValue {
                    attribute :>> num = 850.0;
                }
                attribute :>> lowLevelSetpoint : VolumeValue {
                    attribute :>> num = 150.0;
                }
                attribute :>> currentLevel : VolumeValue {
                    attribute :>> num = 500.0;
                }
            }
            
            flow of condensate : Condensate
                from receiver.outletPort.condensateOut to pump.suctionPort.condensateIn;
            
            part pump : CondensatePump {
                attribute :>> ratedFlowRate : FlowRateValue {
                    attribute :>> num = 150.0;
                }
                attribute :>> ratedDischargeHead : PressureValue {
                    attribute :>> num = 300.0;
                }
                attribute :>> ratedPower : PowerValue {
                    attribute :>> num = 7.5;
                }
                attribute :>> motorEfficiency = 0.92;
                attribute :>> pumpEfficiency = 0.78;
                
                satisfy pumpFlowReq by pump;
                satisfy pumpPressureReq by pump;
            }
            
            flow of condensate : Condensate
                from pump.dischargePort.condensateOut to dischargePiping.inletPort.condensateIn;
            
            part dischargePiping : DischargePiping {
                attribute :>> nominalDiameter = 0.1;
                attribute :>> pipeLength = 50.0;
                attribute :>> pressureDrop : PressureValue {
                    attribute :>> num = 15.0;
                }
            }
            
            flow of condensate : Condensate
                from dischargePiping.outletPort.condensateOut to storageTank.inletPort.condensateIn;
            
            part storageTank : StorageTank {
                attribute :>> storageCapacity : VolumeValue {
                    attribute :>> num = 5000.0;
                }
                attribute :>> currentVolume : VolumeValue {
                    attribute :>> num = 2000.0;
                }
                attribute :>> maxOperatingPressure : PressureValue {
                    attribute :>> num = 500.0;
                }
                attribute :>> maxOperatingTemperature : TemperatureValue {
                    attribute :>> num = 100.0;
                }
            }
            
            part flowTransmitter : FlowTransmitter {
                attribute :>> measurementAccuracy = 0.015;
                attribute :>> calibrationFactor = 1.0;
            }
            
            bind flowTransmitter.measurementPort.condensateIn = dischargePiping.outletPort.condensateOut;
            
            part dischargePressureTransmitter : PressureTransmitter {
                attribute :>> measurementAccuracy = 0.01;
                attribute :>> calibrationFactor = 1.0;
            }
            
            bind dischargePressureTransmitter.measurementPort.condensateIn = pump.dischargePort.condensateOut;
            
            part suctionPressureTransmitter : PressureTransmitter {
                attribute :>> measurementAccuracy = 0.01;
                attribute :>> calibrationFactor = 1.0;
            }
            
            bind suctionPressureTransmitter.measurementPort.condensateIn = pump.suctionPort.condensateIn;
            
            requirement pumpFlowReq : PumpFlowRequirement;
            requirement pumpPressureReq : PumpPressureRequirement;
            requirement systemContinuityReq : SystemContinuityRequirement;
            requirement receiverLevelControlReq : ReceiverLevelControlRequirement;
            
            satisfy systemContinuityReq by condensatePumpingSubsystem;
            satisfy receiverLevelControlReq by receiver, pump;
        }
        
        part def CondensatePumpingSubsystem {
            part receiver : CondensateReceiver;
            part pump : CondensatePump;
            part dischargePiping : DischargePiping;
            part storageTank : StorageTank;
            part flowTransmitter : FlowTransmitter;
            part dischargePressureTransmitter : PressureTransmitter;
            part suctionPressureTransmitter : PressureTransmitter;
        }
    }
}

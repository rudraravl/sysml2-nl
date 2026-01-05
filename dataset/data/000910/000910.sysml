package LiquidRingPumpingSubsystem {
    private import ScalarValues::*;
    private import SI::*;

    package Definitions {
        
        attribute def Pressure {
            attribute value: Real;
            attribute unit: String;
        }
        
        attribute def FlowRate {
            attribute value: Real;
            attribute unit: String;
        }
        
        attribute def Temperature {
            attribute value: Real;
            attribute unit: String;
        }
        
        attribute def RotationalSpeed {
            attribute rpm: Real;
        }
        
        attribute def Power {
            attribute value: Real;
            attribute unit: String;
        }
        
        item def ProcessGas {
            attribute temperature: Temperature;
            attribute pressure: Pressure;
            attribute flowRate: FlowRate;
        }
        
        item def SealingLiquid {
            attribute temperature: Temperature;
            attribute volume: Real;
            attribute pressure: Pressure;
        }
        
        port def GasInletPort {
            attribute inletPressure: Pressure;
            attribute inletTemperature: Temperature;
            in item gas: ProcessGas;
        }
        
        port def GasOutletPort {
            attribute outletPressure: Pressure;
            attribute outletTemperature: Temperature;
            out item gas: ProcessGas;
        }
        
        port def SealLiquidPort {
            attribute liquidPressure: Pressure;
            in item sealLiquid: SealingLiquid;
        }
        
        port def SealLiquidReturnPort {
            attribute returnPressure: Pressure;
            out item usedSealLiquid: SealingLiquid;
        }
        
        port def PowerPort {
            in attribute powerInput: Power;
        }
        
        part def LiquidRingPump {
            attribute nominalFlowRate: FlowRate;
            attribute maxDischargePressure: Pressure;
            attribute impellerSpeed: RotationalSpeed;
            attribute motorPower: Power;
            
            port gasInlet: GasInletPort;
            port gasDischarge: GasOutletPort;
            port sealLiquidInlet: SealLiquidPort;
            port sealLiquidReturn: SealLiquidReturnPort;
            port powerInput: PowerPort;
            
            part impeller {
                attribute diameter: Real;
                attribute bladeCount: Integer;
                attribute rotationSpeed: RotationalSpeed;
            }
            
            part pumpCasing {
                attribute internalVolume: Real;
                part liquidRingChamber {
                    item activeSealLiquid: SealingLiquid;
                }
            }
            
            part driveshaft {
                attribute diameter: Real;
                attribute length: Real;
            }
            
            part electricMotor {
                attribute ratedPower: Power;
                attribute efficiency: Real;
                attribute voltage: Real;
            }
            
            perform action pumpingOperation: PumpGas {
                in gasIn = gasInlet.gas;
                in sealIn = sealLiquidInlet.sealLiquid;
                out gasOut = gasDischarge.gas;
                out sealOut = sealLiquidReturn.usedSealLiquid;
            }
        }
        
        part def SealLiquidTank {
            attribute capacity: Real;
            attribute currentLevel: Real;
            attribute liquidTemperature: Temperature;
            
            port outlet: ~SealLiquidPort;
            port inlet: ~SealLiquidReturnPort;
            
            item storedLiquid: SealingLiquid {
                attribute volume: Real;
            }
        }
        
        part def GasLiquidSeparator {
            attribute separationEfficiency: Real;
            
            port mixedInlet: ~SealLiquidReturnPort;
            port liquidOutlet: SealLiquidPort;
            port gasVentPort: GasOutletPort;
            
            perform action separatePhases: SeparateGasLiquid {
                in mixedFluid = mixedInlet.usedSealLiquid;
                out recoveredLiquid = liquidOutlet.sealLiquid;
                out ventedGas = gasVentPort.gas;
            }
        }
        
        part def HeatExchanger {
            attribute coolingCapacity: Power;
            attribute effectivenessRating: Real;
            
            port hotInlet: SealLiquidPort;
            port cooledOutlet: SealLiquidPort;
            port coolantInlet: GasInletPort;
            port coolantOutlet: GasOutletPort;
            
            perform action coolLiquid: CoolSealLiquid {
                in hotLiquid = hotInlet.sealLiquid;
                in coolant = coolantInlet.gas;
                out cooledLiquid = cooledOutlet.sealLiquid;
                out warmedCoolant = coolantOutlet.gas;
            }
        }
        
        part def ProcessVessel {
            attribute capacity: Real;
            attribute operatingPressure: Pressure;
            attribute currentLevel: Real;
            
            port gasOutlet: GasOutletPort;
            
            item containedGas: ProcessGas {
                attribute volume: Real;
            }
        }
        
        part def DischargeReceiver {
            attribute capacity: Real;
            attribute maxPressure: Pressure;
            attribute currentLevel: Real;
            
            port gasInlet: GasInletPort;
            
            item receivedGas: ProcessGas {
                attribute volume: Real;
            }
        }
        
        part def PressureTransmitter {
            attribute measuredPressure: Pressure;
            attribute accuracy: Real;
            attribute rangeMin: Pressure;
            attribute rangeMax: Pressure;
        }
        
        part def FlowTransmitter {
            attribute measuredFlowRate: FlowRate;
            attribute accuracy: Real;
            attribute rangeMin: FlowRate;
            attribute rangeMax: FlowRate;
        }
        
        part def TemperatureTransmitter {
            attribute measuredTemperature: Temperature;
            attribute accuracy: Real;
            attribute rangeMin: Temperature;
            attribute rangeMax: Temperature;
        }
        
        part def LevelTransmitter {
            attribute measuredLevel: Real;
            attribute accuracy: Real;
        }
        
        action def PumpGas {
            in gasIn: ProcessGas;
            in sealIn: SealingLiquid;
            out gasOut: ProcessGas;
            out sealOut: SealingLiquid;
            
            first start;
            then action formLiquidRing {
                doc /* Centrifugal force throws sealing liquid against casing wall forming ring */
            }
            then action compressGas {
                doc /* Gas enters between impeller blades and liquid ring, gets compressed */
            }
            then action dischargeGas {
                doc /* Compressed gas exits through discharge port */
            }
            then done;
        }
        
        action def SeparateGasLiquid {
            in mixedFluid: SealingLiquid;
            out recoveredLiquid: SealingLiquid;
            out ventedGas: ProcessGas;
        }
        
        action def CoolSealLiquid {
            in hotLiquid: SealingLiquid;
            in coolant: ProcessGas;
            out cooledLiquid: SealingLiquid;
            out warmedCoolant: ProcessGas;
        }
        
        state def PumpOperatingStates {
            entry; then stopped;
            
            state stopped;
            
            transition stopped_to_starting
                first stopped
                accept StartCommand
                then starting;
            
            state starting;
            
            transition starting_to_priming
                first starting
                accept PrimingReady
                then priming;
            
            state priming;
            
            transition priming_to_running
                first priming
                accept RunningReady
                then running;
            
            state running {
                state normalOperation;
                
                state cavitationWarning;
                
                state highTemperature;
                
                transition normal_to_cavitation
                    first normalOperation
                    accept CavitationDetected
                    then cavitationWarning;
                
                transition cavitation_to_normal
                    first cavitationWarning
                    accept CavitationCleared
                    then normalOperation;
                
                transition normal_to_hightemp
                    first normalOperation
                    accept HighTempDetected
                    then highTemperature;
                
                transition hightemp_to_normal
                    first highTemperature
                    accept TempNormalized
                    then normalOperation;
            }
            
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            
            state stopping;
            
            transition stopping_to_stopped
                first stopping
                accept StoppedConfirmed
                then stopped;
            
            state emergency;
            
            transition any_to_emergency
                first stopped
                accept EmergencyStop
                then emergency;
            
            transition any_to_emergency2
                first starting
                accept EmergencyStop
                then emergency;
            
            transition any_to_emergency3
                first priming
                accept EmergencyStop
                then emergency;
            
            transition any_to_emergency4
                first running
                accept EmergencyStop
                then emergency;
        }
        
        requirement def PumpPerformanceRequirement {
            subject pump: LiquidRingPump;
            
            require constraint flowCapability {
                pump.nominalFlowRate.value >= 150.0 and
                pump.nominalFlowRate.value <= 600.0
            }
            
            require constraint pressureCapability {
                pump.maxDischargePressure.value >= 250.0
            }
            
            require constraint motorEfficiency {
                pump.electricMotor.efficiency >= 0.88
            }
        }
        
        requirement def SealLiquidSystemRequirement {
            subject sealSystem;
            
            doc /* Sealing liquid temperature must remain below 65°C to prevent vaporization */
            doc /* Sealing liquid level must be maintained between 60% and 90% of tank capacity */
            doc /* Sealing liquid must be filtered and cooled to maintain pump efficiency */
        }
        
        requirement def SystemSafetyRequirement {
            subject pumpingSystem;
            
            doc /* System must include pressure relief devices to prevent overpressure */
            doc /* Emergency shutdown must stop pump within 5 seconds */
            doc /* Inlet pressure must be maintained above minimum NPSH requirement */
        }
    }
    
    package Usages {
        import Definitions::*;
        
        part liquidRingPumpingSystem {
            
            part sourceVessel: ProcessVessel {
                attribute :>> capacity = 2000.0;
                attribute :>> operatingPressure {
                    attribute :>> value = 80.0;
                    attribute :>> unit = "kPa";
                }
                attribute :>> currentLevel = 0.70;
            }
            
            flow of processGas: ProcessGas
                from sourceVessel.gasOutlet.gas
                to mainPump.gasInlet.gas;
            
            part mainPump: LiquidRingPump {
                attribute :>> nominalFlowRate {
                    attribute :>> value = 300.0;
                    attribute :>> unit = "m3/h";
                }
                attribute :>> maxDischargePressure {
                    attribute :>> value = 350.0;
                    attribute :>> unit = "kPa";
                }
                attribute :>> impellerSpeed {
                    attribute :>> rpm = 1450.0;
                }
                attribute :>> motorPower {
                    attribute :>> value = 22.0;
                    attribute :>> unit = "kW";
                }
                
                part :>> impeller {
                    attribute :>> diameter = 0.45;
                    attribute :>> bladeCount = 18;
                }
                
                part :>> electricMotor {
                    attribute :>> ratedPower {
                        attribute :>> value = 22.0;
                        attribute :>> unit = "kW";
                    }
                    attribute :>> efficiency = 0.92;
                    attribute :>> voltage = 460.0;
                }
                
                exhibit state operatingState: PumpOperatingStates;
            }
            
            part sealTank: SealLiquidTank {
                attribute :>> capacity = 250.0;
                attribute :>> currentLevel = 0.75;
                attribute :>> liquidTemperature {
                    attribute :>> value = 298.15;
                    attribute :>> unit = "K";
                }
            }
            
            flow of sealLiquidSupply: SealingLiquid
                from sealTank.outlet.sealLiquid
                to mainPump.sealLiquidInlet.sealLiquid;
            
            flow of usedSealLiquid: SealingLiquid
                from mainPump.sealLiquidReturn.usedSealLiquid
                to separator.mixedInlet.usedSealLiquid;
            
            part separator: GasLiquidSeparator {
                attribute :>> separationEfficiency = 0.98;
            }
            
            flow of recoveredSealLiquid: SealingLiquid
                from separator.liquidOutlet.sealLiquid
                to cooler.hotInlet.sealLiquid;
            
            part cooler: HeatExchanger {
                attribute :>> coolingCapacity {
                    attribute :>> value = 8.0;
                    attribute :>> unit = "kW";
                }
                attribute :>> effectivenessRating = 0.85;
            }
            
            flow of cooledSealLiquid: SealingLiquid
                from cooler.cooledOutlet.sealLiquid
                to sealTank.inlet.usedSealLiquid;
            
            flow of pumpedGas: ProcessGas
                from mainPump.gasDischarge.gas
                to receiver.gasInlet.gas;
            
            part receiver: DischargeReceiver {
                attribute :>> capacity = 3000.0;
                attribute :>> maxPressure {
                    attribute :>> value = 400.0;
                    attribute :>> unit = "kPa";
                }
                attribute :>> currentLevel = 0.45;
            }
            
            part inletPressureSensor: PressureTransmitter {
                attribute :>> accuracy = 0.015;
                attribute :>> rangeMin {
                    attribute :>> value = 0.0;
                    attribute :>> unit = "kPa";
                }
                attribute :>> rangeMax {
                    attribute :>> value = 200.0;
                    attribute :>> unit = "kPa";
                }
            }
            
            part dischargePressureSensor: PressureTransmitter {
                attribute :>> accuracy = 0.015;
                attribute :>> rangeMin {
                    attribute :>> value = 0.0;
                    attribute :>> unit = "kPa";
                }
                attribute :>> rangeMax {
                    attribute :>> value = 500.0;
                    attribute :>> unit = "kPa";
                }
            }
            
            part flowSensor: FlowTransmitter {
                attribute :>> accuracy = 0.01;
                attribute :>> rangeMin {
                    attribute :>> value = 0.0;
                    attribute :>> unit = "m3/h";
                }
                attribute :>> rangeMax {
                    attribute :>> value = 500.0;
                    attribute :>> unit = "m3/h";
                }
            }
            
            part sealTempSensor: TemperatureTransmitter {
                attribute :>> accuracy = 0.3;
                attribute :>> rangeMin {
                    attribute :>> value = 273.15;
                    attribute :>> unit = "K";
                }
                attribute :>> rangeMax {
                    attribute :>> value = 373.15;
                    attribute :>> unit = "K";
                }
            }
            
            part sealLevelSensor: LevelTransmitter {
                attribute :>> accuracy = 0.02;
            }
            
            satisfy performanceReq: PumpPerformanceRequirement {
                subject pump = mainPump;
            }
            
            satisfy sealSystemReq: SealLiquidSystemRequirement;
            
            satisfy safetyReq: SystemSafetyRequirement;
            
            assert constraint operatingConstraint {
                mainPump.gasInlet.inletPressure.value >= 10.0 and
                mainPump.gasDischarge.outletPressure.value <= 380.0 and
                sealTank.currentLevel >= 0.60 and
                sealTank.currentLevel <= 0.90
            }
        }
    }
}

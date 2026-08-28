package MedicalHeadlightSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value type ColorTemperatureValue :> Real {
        :>> unit = 'K';
    }
    
    value type LuminousFluxValue :> Real {
        :>> unit = 'lm';
    }
    
    value type LuminousIntensityValue :> Real {
        :>> unit = 'cd';
    }
    
    value type BeamAngleValue :> Real {
        :>> unit = 'deg';
    }
    
    value type LengthValue :> Real {
        :>> unit = 'm';
    }
    
    value type MassValue :> Real {
        :>> unit = 'g';
    }
    
    value type VoltageValue :> Real {
        :>> unit = 'V';
    }
    
    value type CurrentValue :> Real {
        :>> unit = 'A';
    }
    
    value type PowerValue :> Real {
        :>> unit = 'W';
    }
    
    value type TemperatureValue :> Real {
        :>> unit = 'degC';
    }
    
    value type ChargeValue :> Real {
        :>> unit = 'Ah';
    }
    
    value type TimeValue :> Real {
        :>> unit = 'h';
    }
    
    value type IntensityLevel :> Integer {
        :>> min = 0;
        :>> max = 5;
    }
    
    // ===== Items =====
    
    item def Light {
        attribute colorTemp : ColorTemperatureValue;
        attribute flux : LuminousFluxValue;
    }
    
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    item def ControlSignal {
        attribute targetLevel : IntensityLevel;
    }
    
    item def StatusReport {
        attribute batteryCharge : ChargeValue;
        attribute internalTemp : TemperatureValue;
        attribute currentLevel : IntensityLevel;
        attribute fault : Boolean;
    }
    
    // ===== Port Definitions =====
    
    port def LightPort {
        out light : Light;
    }
    
    port def LightInPort {
        in light : Light;
    }
    
    port def PowerOutPort {
        out power : ElectricalPower;
    }
    
    port def PowerInPort {
        in power : ElectricalPower;
    }
    
    port def ControlPort {
        out signal : ControlSignal;
    }
    
    port def ControlInPort {
        in signal : ControlSignal;
    }
    
    port def StatusPort {
        out status : StatusReport;
    }
    
    port def StatusInPort {
        in status : StatusReport;
    }
    
    // ===== Components =====
    
    part def LEDIlluminationModule {
        attribute colorTemperature : ColorTemperatureValue = 5500;
        attribute maxFlux : LuminousFluxValue = 1200;
        attribute operatingPower : PowerValue = 15;
        
        port lightOut : LightPort;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port statusOut : StatusPort;
        
        attribute currentLevel : IntensityLevel = 3;
        attribute internalTemp : TemperatureValue = 35;
        
        state def LEDModuleBehavior {
            entry; then Off;
            
            state Off;
            
            state On {
                entry; then Normal;
                
                state Normal {
                    entry action {
                        currentLevel := controlIn.signal.targetLevel;
                    }
                }
                
                state ReducedPower {
                    entry action {
                        currentLevel := 1;
                    }
                }
                
                state ThermalShutdown {
                    entry action {
                        currentLevel := 0;
                    }
                }
                
                transition from Normal to ReducedPower
                    when (internalTemp > 70);
                transition from ReducedPower to ThermalShutdown
                    when (internalTemp > 85);
                transition from ReducedPower to Normal
                    when (internalTemp < 60);
                transition from ThermalShutdown to Off
                    when (internalTemp < 50);
            }
            
            transition from Off to On
                when (powerIn.power.voltage > 0 and controlIn.signal.targetLevel > 0);
            transition from On to Off
                when (powerIn.power.voltage <= 0);
        }
        
        exhibit LEDModuleBehavior;
        
        action def generateLight {
            in level : IntensityLevel;
            out beam : Light;
            
            perform {
                beam.colorTemp := colorTemperature;
                beam.flux := maxFlux * level / 5;
            }
        }
    }
    
    part def FiberOpticGuide {
        attribute length : LengthValue = 1.5;
        attribute transmissionEfficiency : Real = 0.92;
        attribute mass : MassValue = 120;
        
        port lightIn : LightInPort;
        port lightOut : LightPort;
        
        action def transmitLight {
            in input : Light;
            out output : Light;
            
            perform {
                output.colorTemp := input.colorTemp;
                output.flux := input.flux * transmissionEfficiency;
            }
        }
    }
    
    part def OpticalHeadpiece {
        attribute mass : MassValue = 80;
        attribute minBeamAngle : BeamAngleValue = 5;
        attribute maxBeamAngle : BeamAngleValue = 60;
        attribute currentBeamAngle : BeamAngleValue = 20;
        
        port lightIn : LightInPort;
        port lightOut : LightPort;
        
        action def focusBeam {
            in input : Light;
            in angle : BeamAngleValue;
            out output : Light;
            
            perform {
                output.colorTemp := input.colorTemp;
                output.flux := input.flux;
                currentBeamAngle := angle;
            }
        }
        
        action def adjustBeam {
            in angle : BeamAngleValue;
            
            perform {
                if (angle >= minBeamAngle and angle <= maxBeamAngle) {
                    currentBeamAngle := angle;
                }
            }
        }
    }
    
    part def BatteryPack {
        attribute nominalVoltage : VoltageValue = 7.4;
        attribute capacity : ChargeValue = 6.8;
        attribute currentCharge : ChargeValue = 6.8;
        attribute mass : MassValue = 250;
        attribute maxDischargeCurrent : CurrentValue = 3.0;
        
        port powerOut : PowerOutPort;
        port statusOut : StatusPort;
        
        state def BatteryBehavior {
            entry; then Full;
            
            state Full {
                entry action { currentCharge := capacity; }
            }
            
            state Discharging;
            
            state Low {
                entry action { 
                    statusOut.status.batteryCharge := currentCharge;
                    statusOut.status.fault := false;
                }
            }
            
            state Depleted;
            
            transition from Full to Discharging
                when (powerOut.power.current > 0);
            transition from Discharging to Low
                when (currentCharge < 1.0);
            transition from Low to Depleted
                when (currentCharge < 0.1);
            transition from Depleted to Full
                when (currentCharge >= capacity);
        }
        
        exhibit BatteryBehavior;
        
        action def supplyPower {
            out power : ElectricalPower;
            
            perform {
                power.voltage := nominalVoltage;
                power.current := maxDischargeCurrent;
            }
        }
    }
    
    part def PowerManagementUnit {
        attribute efficiency : Real = 0.95;
        attribute outputVoltage : VoltageValue = 12.0;
        attribute maxOutputCurrent : CurrentValue = 1.5;
        
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        port controlIn : ControlInPort;
        port statusOut : StatusPort;
        
        action def regulatePower {
            in input : ElectricalPower;
            in level : IntensityLevel;
            out output : ElectricalPower;
            
            perform {
                output.voltage := outputVoltage;
                output.current := (level / 5) * maxOutputCurrent * efficiency;
            }
        }
    }
    
    part def TemperatureSensor {
        attribute maxOperatingTemp : TemperatureValue = 85;
        attribute warningTemp : TemperatureValue = 70;
        attribute currentReading : TemperatureValue = 35;
        
        port statusOut : StatusPort;
        
        action def measureTemperature {
            out temp : TemperatureValue;
            
            perform {
                temp := currentReading;
                statusOut.status.internalTemp := currentReading;
            }
        }
    }
    
    part def UserInterface {
        attribute currentLevel : IntensityLevel = 3;
        attribute buttonCount : Integer = 3;
        
        port controlOut : ControlPort;
        port statusIn : StatusInPort;
        
        action def increaseIntensity {
            perform {
                if (currentLevel < 5) {
                    currentLevel := currentLevel + 1;
                }
                controlOut.signal.targetLevel := currentLevel;
            }
        }
        
        action def decreaseIntensity {
            perform {
                if (currentLevel > 0) {
                    currentLevel := currentLevel - 1;
                }
                controlOut.signal.targetLevel := currentLevel;
            }
        }
        
        action def setMaxIntensity {
            perform {
                currentLevel := 5;
                controlOut.signal.targetLevel := currentLevel;
            }
        }
        
        action def displayStatus {
            in status : StatusReport;
            perform {
                // Display battery and temperature status to user
            }
        }
    }
    
    part def SystemController {
        attribute lowBatteryThreshold : ChargeValue = 1.0;
        attribute overTempThreshold : TemperatureValue = 70;
        attribute criticalTempThreshold : TemperatureValue = 85;
        
        port statusIn : StatusInPort;
        port controlOut : ControlPort;
        
        state def ControllerBehavior {
            entry; then Monitoring;
            
            state Monitoring {
                entry action {
                    controlOut.signal.targetLevel := 3;
                }
            }
            
            state LowBatteryMode {
                entry action {
                    controlOut.signal.targetLevel := 1;
                }
            }
            
            state ThermalProtectionMode {
                entry action {
                    controlOut.signal.targetLevel := 1;
                }
            }
            
            state EmergencyShutdown {
                entry action {
                    controlOut.signal.targetLevel := 0;
                }
            }
            
            transition from Monitoring to LowBatteryMode
                when (statusIn.status.batteryCharge < lowBatteryThreshold);
            transition from Monitoring to ThermalProtectionMode
                when (statusIn.status.internalTemp > overTempThreshold);
            transition from ThermalProtectionMode to EmergencyShutdown
                when (statusIn.status.internalTemp > criticalTempThreshold);
            transition from LowBatteryMode to Monitoring
                when (statusIn.status.batteryCharge >= lowBatteryThreshold);
            transition from ThermalProtectionMode to Monitoring
                when (statusIn.status.internalTemp < overTempThreshold - 5);
        }
        
        exhibit ControllerBehavior;
    }
    
    // ===== Top-level System =====
    
    part def MedicalHeadlightSystem {
        attribute systemMass : MassValue = 600;
        attribute minOperatingTime : TimeValue = 4.0;
        attribute colorTemperature : ColorTemperatureValue = 5500;
        
        part ledModule : LEDIlluminationModule;
        part fiberGuide : FiberOpticGuide;
        part headpiece : OpticalHeadpiece;
        part battery : BatteryPack;
        part pmu : PowerManagementUnit;
        part tempSensor : TemperatureSensor;
        part ui : UserInterface;
        part controller : SystemController;
        
        // Connections
        connection battery.powerOut to pmu.powerIn;
        connection pmu.powerOut to ledModule.powerIn;
        connection ui.controlOut to controller.statusIn;
        connection controller.controlOut to ledModule.controlIn;
        connection controller.controlOut to pmu.controlIn;
        connection ledModule.statusOut to controller.statusIn;
        connection battery.statusOut to controller.statusIn;
        connection tempSensor.statusOut to controller.statusIn;
        connection ledModule.statusOut to ui.statusIn;
        
        // Light path
        connection ledModule.lightOut to fiberGuide.lightIn;
        connection fiberGuide.lightOut to headpiece.lightIn;
        
        // System-level behavior
        state def SystemOperation {
            entry; then PoweredOff;
            
            state PoweredOff;
            
            state Standby;
            
            state Active {
                entry; then NormalOperation;
                
                state NormalOperation;
                state ConservativeOperation;
                state FaultCondition;
                
                transition from NormalOperation to ConservativeOperation
                    when (controller.statusIn.status.batteryCharge < 1.0 or
                          controller.statusIn.status.internalTemp > 70);
                transition from ConservativeOperation to NormalOperation
                    when (controller.statusIn.status.batteryCharge >= 1.0 and
                          controller.statusIn.status.internalTemp < 65);
                transition from ConservativeOperation to FaultCondition
                    when (controller.statusIn.status.internalTemp > 85);
            }
            
            transition from PoweredOff to Standby
                when (battery.currentCharge > 0);
            transition from Standby to Active
                when (ui.currentLevel > 0);
            transition from Active to Standby
                when (ui.currentLevel == 0);
            transition from Standby to PoweredOff
                when (battery.currentCharge <= 0);
        }
        
        exhibit SystemOperation;
    }
    
    // ===== Requirements =====
    
    requirement def MedicalIlluminationRequirement {
        subject system : MedicalHeadlightSystem;
        
        requirement def ColorTemperatureRequirement {
            subject led : LEDIlluminationModule;
            :>> requirement : led.colorTemperature == 5500;
        }
        
        requirement def FiberOpticLengthRequirement {
            subject guide : FiberOpticGuide;
            :>> requirement : guide.length == 1.5;
        }
        
        requirement def OperatingTimeRequirement {
            subject bat : BatteryPack;
            :>> requirement : bat.capacity >= 6.8;
        }
        
        requirement def ThermalSafetyRequirement {
            subject sensor : TemperatureSensor;
            :>> requirement : sensor.maxOperatingTemp <= 85;
        }
        
        requirement def LowBatteryWarningRequirement {
            subject ctrl : SystemController;
            :>> requirement : ctrl.lowBatteryThreshold <= 1.0;
        }
        
        requirement def IntensityControlRequirement {
            subject iface : UserInterface;
            :>> requirement : iface.currentLevel >= 0 and iface.currentLevel <= 5;
        }
        
        requirement def SystemMassRequirement {
            subject sys : MedicalHeadlightSystem;
            :>> requirement : sys.systemMass <= 800;
        }
        
        requirement def BeamAdjustabilityRequirement {
            subject head : OpticalHeadpiece;
            :>> requirement : head.minBeamAngle >= 5 and head.maxBeamAngle <= 60;
        }
        
        satisfy ColorTemperatureRequirement by ledModule;
        satisfy FiberOpticLengthRequirement by fiberGuide;
        satisfy OperatingTimeRequirement by battery;
        satisfy ThermalSafetyRequirement by tempSensor;
        satisfy LowBatteryWarningRequirement by controller;
        satisfy IntensityControlRequirement by ui;
        satisfy SystemMassRequirement by MedicalHeadlightSystem;
        satisfy BeamAdjustabilityRequirement by headpiece;
    }
}

package EVA_System_Model {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        package AttributeDefinitions {
            attribute def TemperatureValue :> ISQ::temperature;
            attribute def PressureValue :> ISQ::pressure;
            attribute def HeartRateValue :> ISQ::frequency;
            attribute def RespirationRateValue :> ISQ::frequency;
            attribute def VolumeValue :> ISQ::volume;
            attribute def MassValue :> ISQ::mass;
            attribute def PowerValue :> ISQ::power;
            attribute def VoltageValue :> ISQ::electricPotential;
            attribute def CurrentValue :> ISQ::electricCurrent;
            attribute def VolumeFlowRateValue :> ISQ::volumeFlowRate;
            attribute def DurationValue :> ISQ::time;
        }

        package ItemDefinitions {
            item def Oxygen {
                attribute pressure : PressureValue;
                attribute purity : Real;
            }
            item def CarbonDioxide {
                attribute partialPressure : PressureValue;
            }
            item def Water {
                attribute temperature : TemperatureValue;
                attribute flowRate : VolumeFlowRateValue;
            }
            item def ElectricalPower {
                attribute voltage : VoltageValue;
                attribute current : CurrentValue;
            }
            item def TelemetryData {
                attribute suitPressure : PressureValue;
                attribute suitTemperature : TemperatureValue;
                attribute heartRate : HeartRateValue;
                attribute respirationRate : RespirationRateValue;
                attribute batteryLevel : Real;
                attribute oxygenRemaining : VolumeValue;
            }
            item def CommandData {
                attribute commandType : String;
            }
            item def AlertData {
                attribute severity : String;
                attribute alertMessage : String;
            }
            item def BiometricData {
                attribute heartRate : HeartRateValue;
                attribute bodyTemperature : TemperatureValue;
                attribute respirationRate : RespirationRateValue;
            }
        }

        package PortDefinitions {
            port def OxygenSupplyPort {
                out item oxygenSupply : Oxygen;
                in item co2Return : CarbonDioxide;
            }
            port def CoolantPort {
                out item coolantFlow : Water;
                in item coolantReturn : Water;
            }
            port def PowerPort {
                out item powerOut : ElectricalPower;
            }
            port def BiometricPort {
                out item vitals : BiometricData;
            }
            port def CommPort {
                out item telemetry : TelemetryData;
                out item alert : AlertData;
                in item command : CommandData;
            }
            port def DataPort {
                out item telemetry : TelemetryData;
                in item command : CommandData;
            }
        }

        package ActionDefinitions {
            action def MaintainAtmosphere;
            action def ProtectAstronaut;
            action def SupplyOxygen;
            action def ScrubCO2;
            action def CirculateCoolant;
            action def ProvidePower;
            action def ProvideLifeSupport {
                action supplyOxygen : SupplyOxygen;
                action scrubCO2 : ScrubCO2;
                action circulateCoolant : CirculateCoolant;
                action providePower : ProvidePower;
            }
            action def SenseVitals { out data : BiometricData; }
            action def AssessHealth { in data : BiometricData; out status : String; }
            action def GenerateAlert { in status : String; out alert : AlertData; }
            action def MonitorHealth {
                action senseVitals : SenseVitals;
                action assessHealth : AssessHealth;
                action generateAlert : GenerateAlert;
            }
            action def TransmitTelemetry { in data : TelemetryData; }
            action def ReceiveCommand { out cmd : CommandData; }
            action def BroadcastAlert { in alert : AlertData; }
            action def Depressurize;
            action def Repressurize;
            action def Prebreathe;
            action def ExecuteEVA {
                action prebreathe : Prebreathe;
                action depressurize : Depressurize;
                action provideLifeSupport : ProvideLifeSupport;
                action monitorHealth : MonitorHealth;
                action transmitTelemetry : TransmitTelemetry;
                action receiveCommand : ReceiveCommand;
                action repressurize : Repressurize;
            }
        }

        package StateDefinitions {
            state def AirlockStates;
            state def HealthStates;
            state def EVAStates;
        }

        package PartDefinitions {
            part def Astronaut {
                attribute mass : MassValue;
                port lifeSupportPort : OxygenSupplyPort;
                port coolantPort : CoolantPort;
                port bioPort : BiometricPort;
            }

            part def Helmet {
                attribute visorTransparency : Real;
            }
            part def HardUpperTorso;
            part def LowerTorsoAssembly;
            part def ArmAssembly;
            part def GloveAssembly;
            part def BootAssembly;

            part def EMU {
                part helmet : Helmet;
                part hardUpperTorso : HardUpperTorso;
                part lowerTorso : LowerTorsoAssembly;
                part leftArm : ArmAssembly;
                part rightArm : ArmAssembly;
                part leftGlove : GloveAssembly;
                part rightGlove : GloveAssembly;
                part leftBoot : BootAssembly;
                part rightBoot : BootAssembly;
                part astronaut : Astronaut;

                attribute suitPressure : PressureValue;
                attribute suitTemperature : TemperatureValue;

                port suitOxygen : OxygenSupplyPort;
                port suitCoolant : CoolantPort;
                port suitPower : PowerPort;
                port suitBio : BiometricPort;
                port suitComm : CommPort;

                perform action maintainAtmosphere : MaintainAtmosphere;
                perform action protectAstronaut : ProtectAstronaut;
            }

            part def OxygenTank {
                attribute capacity : VolumeValue;
                attribute currentLevel : VolumeValue;
                port oxygenOut : OxygenSupplyPort;
                perform action supplyOxygen : SupplyOxygen;
            }

            part def CO2Scrubber {
                port atmosphereIn : OxygenSupplyPort;
                perform action scrubCO2 : ScrubCO2;
            }

            part def WaterCoolingSystem {
                port coolantSupply : CoolantPort;
                port coolantReturn : CoolantPort;
                perform action circulateCoolant : CirculateCoolant;
            }

            part def Battery {
                attribute capacity : PowerValue;
                attribute currentCharge : Real;
                port powerOut : PowerPort;
                perform action providePower : ProvidePower;
            }

            part def PLSS {
                part oxygenTank : OxygenTank;
                part co2Scrubber : CO2Scrubber;
                part waterCooling : WaterCoolingSystem;
                part battery : Battery;

                port plssOxygen : OxygenSupplyPort;
                port plssCoolant : CoolantPort;
                port plssPower : PowerPort;

                perform action provideLifeSupport : ProvideLifeSupport;
            }

            part def BiometricSensor {
                attribute heartRate : HeartRateValue;
                attribute bodyTemperature : TemperatureValue;
                attribute respirationRate : RespirationRateValue;
                port sensorOut : BiometricPort;
                perform action senseVitals : SenseVitals;
            }

            part def HealthMonitoringSystem {
                part sensors : BiometricSensor;
                port hmsAlert : CommPort;
                port hmsData : DataPort;
                perform action monitorHealth : MonitorHealth;
                perform action assessHealth : AssessHealth;
                perform action generateAlert : GenerateAlert;
                exhibit state healthStates : HealthStates;
            }

            part def CommunicationSubsystem {
                port spacecraftLink : CommPort;
                port internalData : DataPort;
                perform action transmitTelemetry : TransmitTelemetry;
                perform action receiveCommand : ReceiveCommand;
                perform action broadcastAlert : BroadcastAlert;
            }

            part def Airlock {
                attribute pressure : PressureValue;
                attribute doorStatus : String;
                perform action depressurize : Depressurize;
                perform action repressurize : Repressurize;
                exhibit state airlockStates : AirlockStates;
            }

            part def Spacecraft {
                part airlock : Airlock;
                port spacecraftComm : CommPort;
            }

            part def EVA_System {
                part emu : EMU;
                part plss : PLSS;
                part healthMonitor : HealthMonitoringSystem;
                part commSubsystem : CommunicationSubsystem;
                part spacecraft : Spacecraft;
                perform action executeEVA : ExecuteEVA;
                exhibit state evaStates : EVAStates;
            }
        }

        package RequirementDefinitions {
            requirement def EVA_Duration_Req {
                doc /* The EVA system shall support continuous operation for up to 8 hours. */
                attribute maxDuration : DurationValue = 8;
                constraint { maxDuration <= 8 }
            }
            requirement def Suit_Pressure_Req {
                doc /* The EMU shall maintain internal pressure between 29.6 kPa and 30.4 kPa. */
                attribute minPressure : PressureValue = 29.6;
                attribute maxPressure : PressureValue = 30.4;
                constraint { minPressure >= 29.6 and maxPressure <= 30.4 }
            }
            requirement def Thermal_Control_Req {
                doc /* The cooling system shall maintain body temperature between 36.5 and 37.5 degrees C. */
                attribute minTemp : TemperatureValue = 36.5;
                attribute maxTemp : TemperatureValue = 37.5;
                constraint { minTemp >= 36.5 and maxTemp <= 37.5 }
            }
            requirement def CO2_Scrubbing_Req {
                doc /* CO2 partial pressure shall remain below 0.5 kPa. */
                attribute maxCO2Pressure : PressureValue = 0.5;
                constraint { maxCO2Pressure <= 0.5 }
            }
            requirement def Communication_Req {
                doc /* The communication subsystem shall maintain two-way telemetry and command link. */
            }
            requirement def Health_Alert_Req {
                doc /* Health monitoring shall generate alerts within 1 second of detecting out-of-limit vitals. */
                attribute maxResponseTime : ISQ::time = 1;
                constraint { maxResponseTime <= 1 }
            }
        }
    }

    package Usages {
        private import Definitions::*;

        action prebreatheAction : Prebreathe;
        action depressurizeAction : Depressurize;
        action repressurizeAction : Repressurize;
        action provideLifeSupportAction : ProvideLifeSupport;
        action monitorHealthAction : MonitorHealth;
        action transmitTelemetryAction : TransmitTelemetry;
        action receiveCommandAction : ReceiveCommand;
        action broadcastAlertAction : BroadcastAlert;
        action senseVitalsAction : SenseVitals;
        action assessHealthAction : AssessHealth;
        action generateAlertAction : GenerateAlert;

        state airlockStatesUsage : AirlockStates {
            entry; then Pressurized;
            state Pressurized;
            accept 'Start Depressurization' then Depressurizing;
            state Depressurizing {
                do depressurizeAction;
            }
            accept when airlockUsage.pressure < 0.1 then Vacuum;
            state Vacuum;
            accept 'Start Repressurization' then Repressurizing;
            state Repressurizing {
                do repressurizeAction;
            }
            accept when airlockUsage.pressure > 101.0 then Pressurized;
        }

        state healthStatesUsage : HealthStates {
            entry; then Normal;
            state Normal {
                do senseVitalsAction;
                do assessHealthAction;
            }
            accept when biometricSensorUsage.heartRate > 120 then Caution;
            accept when biometricSensorUsage.bodyTemperature > 38.0 then Warning;
            accept when biometricSensorUsage.respirationRate > 30 then Critical;
            state Caution {
                do generateAlertAction;
            }
            accept 'Vitals Normal' then Normal;
            accept when biometricSensorUsage.bodyTemperature > 38.0 then Warning;
            accept when biometricSensorUsage.respirationRate > 30 then Critical;
            state Warning {
                do generateAlertAction;
            }
            accept 'Vitals Normal' then Normal;
            accept when biometricSensorUsage.respirationRate > 30 then Critical;
            state Critical {
                do generateAlertAction;
                do broadcastAlertAction;
            }
            accept 'Vitals Normal' then Normal;
        }

        state evaStatesUsage : EVAStates {
            entry; then Prebreathe;
            state Prebreathe {
                do prebreatheAction;
            }
            accept 'Prebreathe Complete' then Depressurizing;
            state Depressurizing {
                do depressurizeAction;
            }
            accept 'Depressurize Complete' then EVAActive;
            state EVAActive {
                do provideLifeSupportAction;
                do monitorHealthAction;
                do transmitTelemetryAction;
                do receiveCommandAction;
            }
            accept 'Emergency Abort' then EmergencyAbort;
            accept 'EVA Complete' then Returning;
            state EmergencyAbort {
                do broadcastAlertAction;
            }
            accept 'Abort Complete' then Returning;
            state Returning;
            accept 'Astronaut in Airlock' then Repressurizing;
            state Repressurizing {
                do repressurizeAction;
            }
            accept 'Repressurize Complete' then Complete;
            state Complete;
        }

        part airlockUsage : Airlock {
            attribute redefines pressure;
        }

        part biometricSensorUsage : BiometricSensor {
            attribute redefines heartRate;
            attribute redefines bodyTemperature;
            attribute redefines respirationRate;
        }

        part evaSystem : EVA_System {
            connect emu.suitOxygen to plss.plssOxygen;
            connect emu.suitCoolant to plss.plssCoolant;
            connect emu.suitPower to plss.plssPower;
            connect emu.suitBio to healthMonitor.sensors.sensorOut;
            connect healthMonitor.hmsAlert to commSubsystem.spacecraftLink;
            connect healthMonitor.hmsData to commSubsystem.internalData;
            connect commSubsystem.spacecraftLink to spacecraft.spacecraftComm;

            flow of Oxygen
                from plss.oxygenTank.oxygenOut.oxygenSupply
                to emu.suitOxygen.oxygenSupply;
            flow of CarbonDioxide
                from emu.suitOxygen.co2Return
                to plss.co2Scrubber.atmosphereIn.co2Return;
            flow of Water
                from plss.waterCooling.coolantSupply.coolantFlow
                to emu.suitCoolant.coolantFlow;
            flow of Water
                from emu.suitCoolant.coolantReturn
                to plss.waterCooling.coolantReturn.coolantReturn;
            flow of ElectricalPower
                from plss.battery.powerOut.powerOut
                to emu.suitPower.powerOut;
            flow of BiometricData
                from emu.astronaut.bioPort.vitals
                to healthMonitor.sensors.sensorOut.vitals;
            flow of TelemetryData
                from healthMonitor.hmsData.telemetry
                to commSubsystem.internalData.telemetry;
            flow of CommandData
                from commSubsystem.internalData.command
                to healthMonitor.hmsData.command;
            flow of AlertData
                from healthMonitor.hmsAlert.alert
                to commSubsystem.spacecraftLink.alert;
            flow of TelemetryData
                from commSubsystem.spacecraftLink.telemetry
                to spacecraft.spacecraftComm.telemetry;
            flow of CommandData
                from spacecraft.spacecraftComm.command
                to commSubsystem.spacecraftLink.command;

            exhibit state evaStates : EVAStates;
            perform action executeEVA : ExecuteEVA;

            satisfy EVA_Duration_Req;
            satisfy Suit_Pressure_Req;
            satisfy Thermal_Control_Req;
            satisfy CO2_Scrubbing_Req;
            satisfy Communication_Req;
            satisfy Health_Alert_Req;
        }

        allocate provideLifeSupportAction to evaSystem.plss {
            allocate provideLifeSupportAction.supplyOxygen to evaSystem.plss.oxygenTank;
            allocate provideLifeSupportAction.scrubCO2 to evaSystem.plss.co2Scrubber;
            allocate provideLifeSupportAction.circulateCoolant to evaSystem.plss.waterCooling;
            allocate provideLifeSupportAction.providePower to evaSystem.plss.battery;
        }
        allocate monitorHealthAction to evaSystem.healthMonitor {
            allocate monitorHealthAction.senseVitals to evaSystem.healthMonitor.sensors;
            allocate monitorHealthAction.assessHealth to evaSystem.healthMonitor;
            allocate monitorHealthAction.generateAlert to evaSystem.healthMonitor;
        }
        allocate transmitTelemetryAction to evaSystem.commSubsystem;
        allocate receiveCommandAction to evaSystem.commSubsystem;
        allocate broadcastAlertAction to evaSystem.commSubsystem;
        allocate depressurizeAction to evaSystem.spacecraft.airlock;
        allocate repressurizeAction to evaSystem.spacecraft.airlock;
    }
}

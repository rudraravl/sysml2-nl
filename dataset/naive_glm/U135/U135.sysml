package VAD_System {
    import ScalarValues::*;

    // Units
    unit mmHg;
    unit L_per_min;
    unit RPM;
    unit Volt;
    unit Ampere;
    unit bpm;

    // Value Types
    value def Pressure :> Real { unit mmHg; }
    value def FlowRate :> Real { unit L_per_min; }
    value def RotationalSpeed :> Real { unit RPM; }
    value def Voltage :> Real { unit Volt; }
    value def Current :> Real { unit Ampere; }
    value def HeartRate :> Real { unit bpm; }

    // Items
    item def Blood;

    // Ports
    port def BloodFlowPort {
        in item blood: Blood;
        attribute flowRate: FlowRate;
        attribute pressure: Pressure;
    }

    port def ElectricalPowerPort {
        in attribute voltage: Voltage;
        in attribute current: Current;
    }

    port def ControlSignalPort {
        out attribute speedCommand: RotationalSpeed;
    }

    port def SensorDataPort {
        in attribute bloodPressure: Pressure;
        in attribute bloodFlowRate: FlowRate;
        in attribute heartRate: HeartRate;
    }

    port def AlarmPort {
        out attribute alarmMessage: String;
    }

    // Requirements
    requirement def ProvideCirculatorySupport {
        doc /* The VAD shall provide mechanical circulatory support to the patient. */
        subject vad: VAD;
        objective {
            vad.cannula.outlet.bloodIn.flowRate > 0 [L_per_min];
        }
    }

    requirement def MinimizeBloodDamage {
        doc /* The pump shall minimize damage to blood cells. */
        subject pump: RotaryBloodPump;
        objective {
            pump.bearing.isContactless == true;
        }
    }

    requirement def AdjustSpeedToDemand {
        doc /* The control system shall adjust pump speed based on physiological demand. */
        subject controller: ControlSystem;
        objective {
            controller.pumpSpeedCommand.speedCommand >= 0 [RPM];
        }
    }

    requirement def EnsureContinuousPower {
        doc /* The power module shall ensure continuous power supply. */
        subject power: PowerModule;
        objective {
            power.backupBattery.chargeLevel > 0;
        }
    }

    // Parts
    part def VAD {
        requirement circulatorySupport: ProvideCirculatorySupport;
        requirement bloodDamage: MinimizeBloodDamage;
        requirement speedAdjustment: AdjustSpeedToDemand;
        requirement continuousPower: EnsureContinuousPower;

        part pump: RotaryBloodPump {
            port in powerIn: ElectricalPowerPort;
            port in speedControl: ControlSignalPort;
            port in bloodIn: BloodFlowPort;
            port out bloodOut: BloodFlowPort;
            
            part impeller: Impeller {
                attribute speed: RotationalSpeed;
            }
            part motor: BrushlessMotor {
                port in powerIn: ElectricalPowerPort;
                attribute mechanicalDrive: RotationalSpeed;
            }
            part bearing: MagneticBearing {
                attribute isContactless: Boolean = true;
            }
            part housing: BiocompatibleHousing;
            
            action pumpBlood {
                in blood: Blood;
                out pressurizedBlood: Blood;
            }
        }

        part cannula: CannulaSystem {
            part inlet: InletCannula {
                port out bloodOut: BloodFlowPort;
            }
            part outlet: OutletCannula {
                port in bloodIn: BloodFlowPort;
            }
        }

        part controller: ControlSystem {
            port in sensorData: SensorDataPort;
            port out pumpSpeedCommand: ControlSignalPort;
            port out alarmOut: AlarmPort;
            port in powerIn: ElectricalPowerPort;

            part microprocessor: Microprocessor;
            part sensorArray: SensorArray {
                port out sensorDataOut: SensorDataPort;
            }
            part alarmManager: AlarmManager {
                port in faultCondition: Boolean;
                port out alarmOut: AlarmPort;
            }

            state def ControlBehavior {
                state Monitoring;
                state Adjusting;
                state AlarmState;
                
                transition monitoring_to_adjusting
                    source Monitoring
                    target Adjusting
                    when sensorData.heartRate > 100 [bpm];
                    
                transition adjusting_to_monitoring
                    source Adjusting
                    target Monitoring
                    when sensorData.heartRate <= 100 [bpm];
                    
                transition any_to_alarm
                    source Monitoring
                    target AlarmState
                    when sensorData.bloodFlowRate < 2 [L_per_min];
            }
            
            exhibit state behavior: ControlBehavior;
            
            connect sensorArray.sensorDataOut to sensorData;
            connect alarmManager.alarmOut to alarmOut;
        }

        part power: PowerModule {
            port in externalPower: ElectricalPowerPort;
            port out pumpPower: ElectricalPowerPort;
            port out controllerPower: ElectricalPowerPort;

            part powerConverter: PowerConverter {
                port in powerIn: ElectricalPowerPort;
                port out powerOut: ElectricalPowerPort;
            }
            part backupBattery: BackupBattery {
                attribute chargeLevel: Real = 1.0;
                port out powerOut: ElectricalPowerPort;
            }
            
            connect externalPower to powerConverter.powerIn;
            connect powerConverter.powerOut to pumpPower;
            connect backupBattery.powerOut to pumpPower;
        }

        connect cannula.inlet.bloodOut to pump.bloodIn;
        connect pump.bloodOut to cannula.outlet.bloodIn;
        connect power.pumpPower to pump.powerIn;
        connect power.controllerPower to controller.powerIn;
        connect controller.pumpSpeedCommand to pump.speedControl;
    }

    part def RotaryBloodPump;
    part def Impeller;
    part def BrushlessMotor;
    part def MagneticBearing;
    part def BiocompatibleHousing;
    part def CannulaSystem;
    part def InletCannula;
    part def OutletCannula;
    part def ControlSystem;
    part def Microprocessor;
    part def SensorArray;
    part def AlarmManager;
    part def PowerModule;
    part def PowerConverter;
    part def BackupBattery;
}

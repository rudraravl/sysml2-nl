package HeadacheHat {
    package Definitions {
        attribute def Temperature :> Real {
            unit 'K';
        }
        attribute def CelsiusTemperature :> Real {
            unit '°C';
        }
        attribute def Pressure :> Real {
            unit 'kPa';
        }
        attribute def Duration :> Real {
            unit 'min';
        }
        attribute def Mass :> Real {
            unit 'g';
        }
        attribute def Energy :> Real {
            unit 'kJ';
        }
        attribute def Length :> Real {
            unit 'cm';
        }

        item def CoolingGel {
            attribute thermalCapacity : Energy;
            attribute initialTemp : CelsiusTemperature;
        }

        item def ThermalEnergy {
            attribute amount : Energy;
        }

        port def ThermalPort {
            out item thermalEnergy : ThermalEnergy;
            in attribute skinTemp : CelsiusTemperature;
        }

        port def CompressionPort {
            out attribute appliedPressure : Pressure;
        }

        port def SensorPort {
            out attribute measuredTemp : CelsiusTemperature;
        }

        port def ControlPort {
            in attribute command : String;
            out attribute status : String;
        }
    }

    package Parts {
        part def FabricShell {
            attribute material : String = "Neoprene";
            attribute adjustability : Boolean = true;
            attribute thickness : Length = 0.5;
            port slotThermal : Definitions::ThermalPort[4];
            port strapAnchor;
        }

        part def GelPack {
            attribute reusable : Boolean = true;
            attribute mass : Definitions::Mass = 120;
            attribute frozenState : Boolean = false;
            attribute storedEnergy : Definitions::Energy = 15.0;
            attribute currentTemp : Definitions::CelsiusTemperature = 20.0;
            port thermalOut : Definitions::ThermalPort;

            action def Freeze {
                in attribute targetTemp : Definitions::CelsiusTemperature = -18.0;
                out attribute frozen : Boolean;
            }

            perform action freezeGel : Freeze {
                frozenState := true;
                currentTemp := -18.0;
            }
        }

        part def ElasticStrap {
            attribute elasticity : Real = 0.8;
            attribute maxPressure : Definitions::Pressure = 4.0;
            attribute currentPressure : Definitions::Pressure = 0.0;
            port compressionOut : Definitions::CompressionPort;
            port anchorPoint;
        }

        part def TemperatureSensor {
            attribute rangeMin : Definitions::CelsiusTemperature = -10.0;
            attribute rangeMax : Definitions::CelsiusTemperature = 50.0;
            attribute accuracy : Definitions::CelsiusTemperature = 0.5;
            attribute measuredTemp : Definitions::CelsiusTemperature;
            port sensorOut : Definitions::SensorPort;

            action def Measure {
                out attribute temp : Definitions::CelsiusTemperature;
            }

            perform action measureTemp : Measure {
                measuredTemp := measuredTemp;
            }
        }

        part def SafetyController {
            attribute safeMinTemp : Definitions::CelsiusTemperature = 5.0;
            attribute recommendedDuration : Definitions::Duration = 20.0;
            attribute sessionActive : Boolean = false;
            attribute alarmTriggered : Boolean = false;
            port controlIn : Definitions::ControlPort;
            port sensorIn : Definitions::SensorPort[2];

            action def MonitorSession {
                in attribute temps : Definitions::CelsiusTemperature[2];
                in attribute elapsed : Definitions::Duration;
                out attribute stopTherapy : Boolean;
            }

            perform action monitor : MonitorSession {
                if (temps(1) < safeMinTemp or temps(2) < safeMinTemp) {
                    stopTherapy := true;
                    alarmTriggered := true;
                    sessionActive := false;
                } else if (elapsed >= recommendedDuration) {
                    stopTherapy := true;
                    sessionActive := false;
                } else {
                    stopTherapy := false;
                }
            }
        }
    }

    package System {
        part HeadacheHatDevice {
            part shell : Parts::FabricShell;
            part gelPacks : Parts::GelPack[4];
            part strap : Parts::ElasticStrap;
            part sensors : Parts::TemperatureSensor[2];
            part controller : Parts::SafetyController;

            connection thermalConnections connect shell.slotThermal to gelPacks.thermalOut;
            connection compressionConnection connect strap.compressionOut to shell.strapAnchor;
            connection sensorConnections connect sensors.sensorOut to controller.sensorIn;

            attribute therapyActive : Boolean = false;
            attribute sessionElapsed : Definitions::Duration = 0.0;

            state def TherapySession {
                entry action startTherapy {
                    therapyActive := true;
                    controller.sessionActive := true;
                }

                state Preparing {
                    entry action prepareGelPacks {
                        gelPacks.freezeGel();
                    }
                    transition to Inserting
                        when gelPacks.frozenState == true;
                }

                state Inserting {
                    entry action insertPacks {
                        // Frozen gel packs inserted into shell slots
                    }
                    transition to Wearing
                        when gelPacks.currentTemp <= 0.0;
                }

                state Wearing {
                    entry action donHat {
                        strap.currentPressure := 2.0;
                    }
                    transition to Active
                        when strap.currentPressure > 0.0;
                }

                state Active {
                    do action deliverTherapy {
                        sensors.measureTemp();
                        controller.monitor(
                            temps := [sensors(1).measuredTemp, sensors(2).measuredTemp],
                            elapsed := sessionElapsed
                        );
                        sessionElapsed := sessionElapsed + 1.0;
                    }
                    transition to Stopped
                        when controller.alarmTriggered == true
                        or sessionElapsed >= controller.recommendedDuration;
                }

                state Stopped {
                    entry action stopTherapy {
                        therapyActive := false;
                        controller.sessionActive := false;
                    }
                    transition to Preparing
                        when therapyActive == false;
                }
            }

            exhibit state therapyBehavior : TherapySession;
        }
    }

    package Requirements {
        requirement def ColdTherapy {
            attribute coolingCapacity : Definitions::Energy = 60.0;
            subject device : System::HeadacheHatDevice;
            objective {
                doc /* The device shall deliver targeted cold therapy using frozen reusable gel packs. */
            }
            require device.gelPacks->size() == 4;
            require device.gelPacks.storedEnergy->sum() >= coolingCapacity;
        }

        requirement def CompressionTherapy {
            attribute targetPressure : Definitions::Pressure = 2.0;
            subject device : System::HeadacheHatDevice;
            objective {
                doc /* The device shall apply gentle, consistent compression via an adjustable elastic strap. */
            }
            require device.strap.currentPressure <= device.strap.maxPressure;
            require device.strap.currentPressure >= targetPressure;
        }

        requirement def SafetyMonitoring {
            attribute minSafeTemp : Definitions::CelsiusTemperature = 5.0;
            subject device : System::HeadacheHatDevice;
            objective {
                doc /* The device shall monitor skin temperature at two contact points and stop therapy if unsafe. */
            }
            require device.sensors->size() == 2;
            require device.controller.safeMinTemp == minSafeTemp;
            require device.controller.alarmTriggered == true
                if device.sensors.measuredTemp->min() < minSafeTemp;
        }

        requirement def SessionDuration {
            attribute recommended : Definitions::Duration = 20.0;
            subject device : System::HeadacheHatDevice;
            objective {
                doc /* The device shall support a recommended therapy session of 20 minutes. */
            }
            require device.controller.recommendedDuration == recommended;
        }

        requirement def Reusability {
            subject device : System::HeadacheHatDevice;
            objective {
                doc /* The device shall be reusable with removable, reusable cooling gel packs. */
            }
            require device.gelPacks.reusable == true;
            require device.shell.material == "Neoprene";
        }

        requirement HeadacheHatRequirements {
            subject device : System::HeadacheHatDevice;
            objective {
                doc /* The Headache Hat shall provide non-pharmaceutical relief from headaches and migraines
                       through combined cold therapy and gentle compression in a safe, comfortable, reusable manner. */
            }
            satisfy by ColdTherapy;
            satisfy by CompressionTherapy;
            satisfy by SafetyMonitoring;
            satisfy by SessionDuration;
            satisfy by Reusability;
        }
    }
}

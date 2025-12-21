// Create a central controller with a temperature sensor that is able to log data.
package CentralControllerTemperatureLoggingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import Time::*;
    
    package ItemDefinitions {
        item def TemperatureReading {
            attribute timestamp : Time::DateTime;
            attribute value : ISQ::ThermodynamicTemperatureValue;
            attribute sensorId : String;
        }
        
        item def LogEntry {
            attribute entryId : Integer;
            attribute timestamp : Time::DateTime;
            attribute reading : TemperatureReading;
        }
    }
    
    package SignalDefinitions {
        signal def StartLoggingSignal;
        signal def StopLoggingSignal;
        signal def TemperatureDataSignal {
            attribute reading : ItemDefinitions::TemperatureReading;
        }
        signal def LogStoredSignal {
            attribute entryId : Integer;
        }
    }
    
    package PortDefinitions {
        port def TemperatureDataPort {
            out item temperatureData : ItemDefinitions::TemperatureReading;
        }
        
        port def LogCommandPort {
            in item logData : ItemDefinitions::TemperatureReading;
        }
        
        port def ControlPort {
            in StartLoggingSignal;
            in StopLoggingSignal;
        }
        
        port def StatusPort {
            out LogStoredSignal;
        }
    }
    
    package PartDefinitions {
        part def TemperatureSensor {
            attribute sensorId : String;
            attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
            attribute samplingInterval : ISQ::DurationValue;
            attribute isActive : Boolean;
            
            port dataPort : PortDefinitions::TemperatureDataPort;
            
            perform action measureTemperature {
                out reading : ItemDefinitions::TemperatureReading;
                language "Alf"
                /*
                 * reading = new TemperatureReading();
                 * reading.value = currentTemperature;
                 * reading.timestamp = Time::now();
                 * reading.sensorId = sensorId;
                 */
            }
            
            perform action performSelfTest;
            
            exhibit state sensorStates {
                entry action initialize;
                
                state inactive {
                    entry action powerDown;
                }
                
                state active {
                    entry action powerUp;
                    
                    state idle;
                    
                    state sensing {
                        do action continuousSensing {
                            language "Alf"
                            /*
                             * while (isActive) {
                             *     var reading : TemperatureReading = null;
                             *     measureTemperature(out reading);
                             *     send new TemperatureDataSignal(reading = reading) to dataPort;
                             * }
                             */
                        }
                    }
                    
                    transition idle_to_sensing
                        first idle
                        accept StartLoggingSignal
                        then sensing;
                    
                    transition sensing_to_idle
                        first sensing
                        accept StopLoggingSignal
                        then idle;
                }
                
                transition initialize then inactive;
                
                transition inactive_to_active
                    first inactive
                    accept ActivateSignal
                    do performSelfTest
                    then active;
                
                transition active_to_inactive
                    first active
                    accept DeactivateSignal
                    then inactive;
            }
        }
        
        part def DataLogger {
            attribute maxCapacity : Integer;
            attribute currentCount : Integer;
            attribute logEntries : ItemDefinitions::LogEntry[*] ordered;
            attribute nextEntryId : Integer;
            
            port logPort : PortDefinitions::LogCommandPort;
            port statusPort : PortDefinitions::StatusPort;
            
            perform action storeReading {
                in reading : ItemDefinitions::TemperatureReading;
                out entryId : Integer;
                language "Alf"
                /*
                 * var entry : LogEntry = new LogEntry();
                 * entry.entryId = nextEntryId;
                 * entry.timestamp = Time::now();
                 * entry.reading = reading;
                 * 
                 * if (currentCount >= maxCapacity) {
                 *     logEntries->removeAt(1);
                 *     currentCount = currentCount - 1;
                 * }
                 * 
                 * logEntries->add(entry);
                 * currentCount = currentCount + 1;
                 * entryId = nextEntryId;
                 * nextEntryId = nextEntryId + 1;
                 */
            }
            
            perform action clearLog {
                language "Alf"
                /*
                 * logEntries->clear();
                 * currentCount = 0;
                 */
            }
            
            perform action retrieveEntries {
                out entries : ItemDefinitions::LogEntry[*];
                language "Alf"
                /*
                 * entries = logEntries;
                 */
            }
            
            exhibit state loggerStates {
                entry action initializeLogger;
                
                state ready;
                
                state storing {
                    do storeReading;
                }
                
                transition ready_to_storing
                    first ready
                    accept dataSignal : SignalDefinitions::TemperatureDataSignal via logPort
                    then storing;
                
                transition storing_to_ready
                    first storing
                    do action notifyStored {
                        language "Alf"
                        /*
                         * send new LogStoredSignal(entryId = nextEntryId - 1) to statusPort;
                         */
                    }
                    then ready;
            }
        }
        
        part def CentralController {
            attribute controllerId : String;
            attribute isOperational : Boolean;
            attribute loggingEnabled : Boolean;
            
            port controlPort : PortDefinitions::ControlPort;
            port statusPort : PortDefinitions::StatusPort;
            
            part temperatureSensor : TemperatureSensor {
                :>> sensorId = "TEMP_SENSOR_01";
                :>> samplingInterval = 1.0[s];
                :>> currentTemperature = 298.15[K];
            }
            
            part dataLogger : DataLogger {
                :>> maxCapacity = 1000;
                :>> currentCount = 0;
                :>> nextEntryId = 1;
            }
            
            connection sensorToLogger connect temperatureSensor.dataPort to dataLogger.logPort;
            
            perform action startLogging {
                language "Alf"
                /*
                 * loggingEnabled = true;
                 * send new StartLoggingSignal() to temperatureSensor;
                 */
            }
            
            perform action stopLogging {
                language "Alf"
                /*
                 * loggingEnabled = false;
                 * send new StopLoggingSignal() to temperatureSensor;
                 */
            }
            
            exhibit state controllerStates {
                entry action initializeController;
                
                state offline;
                
                state online {
                    entry action activateSensor {
                        language "Alf"
                        /*
                         * send new ActivateSignal() to temperatureSensor;
                         */
                    }
                    
                    state idle {
                        entry action waitForCommand;
                    }
                    
                    state logging {
                        entry startLogging;
                        exit stopLogging;
                    }
                    
                    transition idle_to_logging
                        first idle
                        accept StartLoggingSignal via controlPort
                        then logging;
                    
                    transition logging_to_idle
                        first logging
                        accept StopLoggingSignal via controlPort
                        then idle;
                }
                
                transition initializeController then offline;
                
                transition offline_to_online
                    first offline
                    accept SystemStartSignal
                    then online;
                
                transition online_to_offline
                    first online
                    accept SystemShutdownSignal
                    then offline;
            }
        }
    }
    
    package RequirementDefinitions {
        requirement def TemperatureSensingRequirement {
            doc /* The system shall sense temperature at regular intervals. */
            
            subject sensor : PartDefinitions::TemperatureSensor;
            
            require constraint {
                sensor.samplingInterval > 0.0[s]
            }
        }
        
        requirement def DataLoggingRequirement {
            doc /* The system shall log temperature readings with timestamp and sensor identification. */
            
            subject logger : PartDefinitions::DataLogger;
            
            require constraint {
                logger.maxCapacity >= 100
            }
        }
        
        requirement def ControllerOperationalRequirement {
            doc /* The central controller shall manage sensor activation and data logging operations. */
            
            subject controller : PartDefinitions::CentralController;
            
            require constraint {
                controller.isOperational implies controller.temperatureSensor.isActive
            }
        }
    }
    
    package Usages {
        private import PartDefinitions::*;
        private import RequirementDefinitions::*;
        
        part centralControllerSystem : CentralController {
            :>> controllerId = "CTRL_MAIN_01";
            :>> isOperational = true;
            :>> loggingEnabled = false;
            
            satisfy tempSensingReq : TemperatureSensingRequirement by temperatureSensor;
            satisfy dataLoggingReq : DataLoggingRequirement by dataLogger;
            satisfy operationalReq : ControllerOperationalRequirement by centralControllerSystem;
        }
    }
}

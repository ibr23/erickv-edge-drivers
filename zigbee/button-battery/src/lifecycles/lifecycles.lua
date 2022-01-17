-- Copyright 2022 Erick Israel Vazquez Neri
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
local battery = require "st.capabilities".battery
local button = require "st.capabilities".button

local PowerConfiguration = require "st.zigbee.zcl.clusters".PowerConfiguration
local OnOff = require "st.zigbee.zcl.clusters".OnOff
local OnOffButton = require "custom".OnOffButton
local ReadTuyaCluster = require "custom".ReadTuyaCluster

local send_cluster_bind_request = require "emitter".send_cluster_bind_request
local send_attr_configure_reporting = require "emitter".send_attr_configure_reporting
local send_button_capability_setup = require "emitter".send_button_capability_setup


-- generates endpoint reference based
-- on component id string reference.
--
-- @param component_id string
local function _component_to_endpoint(_, component_id)
    local ep = component_id:match("button(%d)")
    return ep and tonumber(ep) or 1
end


-- generates component id reference
-- based on endpoint notified by
-- _component_to_endpoint.
--
-- @param ep number (endpoint)
local function _endpoint_to_component(_, ep)
  return tonumber(ep) == 1 and "main" or "button"..ep
end


-- init lifecycle
--
-- handler component vs endpoint
-- configuration for consistency
--
-- @param device ZigbeeDevice
local function init(_, device)
  device:set_component_to_endpoint_fn(_component_to_endpoint)
  device:set_endpoint_to_component_fn(_endpoint_to_component)
end


-- added lifecycle
--
-- handles initual
-- state configuration
--
-- @param device ZigbeeDevice
local function added(_, device)
  return send_button_capability_setup(
    device,
    device:component_count(),
    { "pushed", "double", "held" })
end


-- doConfigure lifecycle
--
-- handles cluster attribute
-- configuration of report and
-- request binding
--
-- @param driver ZigbeeDriver
-- @param device ZigbeeDevice
local function do_configure(driver, device)
  local err = "failed to configure reporting: "
  local hub_zigbee_eui = driver.environment_info.hub_zigbee_eui
  -- [[
  -- battery capability setup
  -- ]]
  assert(device:supports_capability_by_id(battery.ID), "<battery> capability not supported")
  assert(send_cluster_bind_request(
    device, hub_zigbee_eui, PowerConfiguration.ID))
  assert(send_attr_configure_reporting(
    device, PowerConfiguration.attributes.BatteryPercentageRemaining),
    err.."PowerConfiguration.BatteryPercentageRemaining")
  -- assert(send_attr_configure_reporting(                       TODO: DEFINE HOW MUCH IMPORTANT IT
  --   device, PowerConfiguration.attributes.BatteryVoltage),    IT TO SUBSCRIBE TO BatteryVoltage
  --   err.."PowerConfiguration.BatteryVoltage")

  --[[
  -- button capability setup
  --]]
  assert(device:supports_capability_by_id(button.ID), "<button> capability not supported")
  assert(send_cluster_bind_request(device, hub_zigbee_eui, OnOff.ID))
  -- TODO: CHECK PURPOSE OF DeviceTemperatureConfiguration CLUSTER
  -- TODO: CHECK PURPOSE OF Identify.IdentifyTime CLUSTER
  -- TODO: CHECK PURPOSE OF Groups CLUSTER
  -- Send ZigbeeMesssageTx
  assert(pcall(device.send, device, ReadTuyaCluster(device)))
  assert(pcall(device.send, device, OnOffButton:read(device)))
  assert(pcall(device.send, device ,PowerConfiguration.attributes.BatteryPercentageRemaining:read(device)))
  assert(pcall(device.send, device, PowerConfiguration.attributes.BatteryVoltage:read(device)))
  assert(pcall(device.send, device, OnOffButton:write(device, 0x30)))
  assert(pcall(device.send, device, OnOffButton:read(device)))

  -- Submit configuration
  assert(pcall(device.configure, device))
  assert(pcall(device.refresh, device))
end


return {
  init=init,
  added=added,
  do_configure=do_configure
}
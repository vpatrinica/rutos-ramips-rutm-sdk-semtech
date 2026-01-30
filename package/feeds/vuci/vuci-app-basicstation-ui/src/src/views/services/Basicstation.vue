<template>
  <a-tabs :default-active-key="activeTab" class="basicstation-tabs">
    <a-tab-pane key="general" :tab="$t('General Settings')">
      <vuci-form config="basicstation">
        <!-- Station Identity -->
        <vuci-named-section
          name="station"
          :title="$t('Station Identity')"
          v-slot="{ s }"
        >
          <vuci-form-item-input
            :uci-section="s"
            :label="$t('Interface for station ID generation')"
            name="idGenIf"
            required
            :help="$t('Station ID is derived from the MAC address of the chosen interface')"
          />
          <vuci-form-item-input
            :uci-section="s"
            :label="$t('Station ID')"
            name="stationid"
            readonly
            disabled
            :help="$t('Click save and apply to generate station ID')"
          />
        </vuci-named-section>

        <!-- Authentication -->
        <vuci-named-section
          name="auth"
          :title="$t('Authentication')"
          v-slot="{ s }"
        >
          <vuci-form-item-select
            :uci-section="s"
            :label="$t('Credentials')"
            name="cred"
            :options="credOptions"
            :help="$t('Credentials for LNS (TC) or CUPS (CUPS)')"
          />
          <vuci-form-item-select
            :uci-section="s"
            :label="$t('Authentication mode')"
            name="mode"
            :options="modeOptions"
            :help="$t('Authentication mode for server connection')"
          />
          <vuci-form-item-input
            :uci-section="s"
            :label="$t('Server address')"
            name="addr"
            required
          />
          <vuci-form-item-input
            :uci-section="s"
            :label="$t('Port')"
            name="port"
            required
            rules="uinteger"
          />
          <!-- Token for serverAndClientToken mode -->
          <vuci-form-item-input
            v-if="s.mode === 'serverAndClientToken'"
            :uci-section="s"
            :label="$t('Authorization token')"
            name="token"
            required
          />
          <!-- Certificate uploads for serverAndClient mode -->
          <tlt-form-model-item
            v-if="s.mode === 'serverAndClient'"
            :label="$t('Private key (tc.key)')"
            :help="$t('Key will be saved to /etc/basicstation/tc.key')"
          >
            <tlt-upload
              instant
              name="key"
              action="/api/basicstation/services/basicstation/upload"
            />
          </tlt-form-model-item>
          <tlt-form-model-item
            v-if="s.mode === 'serverAndClient'"
            :label="$t('Client certificate (tc.crt)')"
            :help="$t('Certificate will be saved to /etc/basicstation/tc.crt')"
          >
            <tlt-upload
              instant
              name="crt"
              action="/api/basicstation/services/basicstation/upload"
            />
          </tlt-form-model-item>
          <!-- CA certificate for any TLS mode -->
          <tlt-form-model-item
            v-if="s.mode !== 'no'"
            :label="$t('CA certificate (tc.trust)')"
            :help="$t('Certificate will be saved to /etc/basicstation/tc.trust')"
          >
            <tlt-upload
              instant
              name="trust"
              action="/api/basicstation/services/basicstation/upload"
            />
          </tlt-form-model-item>
        </vuci-named-section>

        <!-- Radio Configuration -->
        <vuci-named-section
          name="sx130x"
          :title="$t('Radio Configuration')"
          v-slot="{ s }"
        >
          <vuci-form-item-select
            :uci-section="s"
            :label="$t('Communication interface')"
            name="comif"
            :options="[['usb', 'USB']]"
            :help="$t('Currently only USB devices are supported')"
          />
          <vuci-form-item-input
            :uci-section="s"
            :label="$t('Device path')"
            name="devpath"
            required
            placeholder="/dev/ttyACM0"
          />
          <vuci-form-item-switch
             :uci-section="s"
             :label="$t('PPS')"
             name="pps"
             :help="$t('PPS (pulse per second) provided by GPS device or other source')"
          />
          <vuci-form-item-switch
             :uci-section="s"
             :label="$t('Public network')"
             name="public"
             :help="$t('Public or private LoRaWAN network')"
          />
          <vuci-form-item-select
            :uci-section="s"
            :label="$t('Clock source')"
            name="clksrc"
            :options="[['0', 'Radio 0'], ['1', 'Radio 1']]"
          />
          <vuci-form-item-select
            :uci-section="s"
            :label="$t('Radio 0')"
            name="radio0"
            :options="rfConfOptions"
          />
          <vuci-form-item-select
            :uci-section="s"
            :label="$t('Radio 1')"
            name="radio1"
            :options="rfConfOptions"
          />
        </vuci-named-section>

        <!-- Logging -->
        <vuci-named-section
          name="station"
          :title="$t('Logging')"
          v-slot="{ s }"
        >
          <vuci-form-item-select
            :uci-section="s"
            :label="$t('Level')"
            name="logLevel"
            :options="logLevelOptions"
          />
          <vuci-form-item-input
            :uci-section="s"
            :label="$t('Size (MB)')"
            name="logSize"
            rules="range(1,10)"
          />
          <vuci-form-item-input
            :uci-section="s"
            :label="$t('Rotate')"
            name="logRotate"
            rules="range(1,10)"
          />
        </vuci-named-section>
      </vuci-form>
    </a-tab-pane>

    <a-tab-pane key="advanced" :tab="$t('Advanced Settings')">
      <vuci-form config="basicstation">
        <!-- RF Configuration -->
        <vuci-typed-section
          type="rfconf"
          :title="$t('RF Configuration')"
          :columns="rfConfColumns"
          addremove
        >
          <template #type="{ s }">
            <vuci-form-item-select :uci-section="s" name="type" :options="[['SX1250', 'SX1250']]" />
          </template>
          <template #txEnable="{ s }">
            <vuci-form-item-switch :uci-section="s" name="txEnable" />
          </template>
          <template #freq="{ s }">
            <vuci-form-item-input :uci-section="s" name="freq" rules="uinteger" />
          </template>
          <template #antennaGain="{ s }">
            <vuci-form-item-input :uci-section="s" name="antennaGain" rules="uinteger" />
          </template>
          <template #rssiOffset="{ s }">
            <vuci-form-item-input :uci-section="s" name="rssiOffset" rules="float" />
          </template>
          <template #useRssiTcomp="{ s }">
            <vuci-form-item-select :uci-section="s" name="useRssiTcomp" :options="rssiTcompOptions" />
          </template>
        </vuci-typed-section>

        <!-- RSSI Tcomp -->
        <vuci-typed-section
          type="rssitcomp"
          :title="$t('RSSI Tcomp')"
          :columns="rssiTcompColumns"
          addremove
        >
          <template #coeff_a="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_a" rules="float" />
          </template>
          <template #coeff_b="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_b" rules="float" />
          </template>
          <template #coeff_c="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_c" rules="float" />
          </template>
          <template #coeff_d="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_d" rules="float" />
          </template>
          <template #coeff_e="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_e" rules="float" />
          </template>
        </vuci-typed-section>

        <!-- TX Gain Lookup Table -->
        <vuci-typed-section
          type="txlut"
          :title="$t('TX Gain Lookup Table')"
          :columns="txLutColumns"
          addremove
        >
          <template #rfPower="{ s }">
            <vuci-form-item-input :uci-section="s" name="rfPower" rules="uinteger" />
          </template>
          <template #paGain="{ s }">
            <vuci-form-item-switch :uci-section="s" name="paGain" />
          </template>
          <template #pwrIdx="{ s }">
            <vuci-form-item-input :uci-section="s" name="pwrIdx" rules="range(0,22)" />
          </template>
          <template #usedBy="{ s }">
            <vuci-form-item-select :uci-section="s" name="usedBy" :options="rfConfOptions" multiple />
          </template>
        </vuci-typed-section>
      </vuci-form>
    </a-tab-pane>

    <a-tab-pane key="log" :tab="$t('Log Messages')">
      <tlt-card :title="$t('Log Messages')">
        <div class="log-container">
          <pre>{{ logContent }}</pre>
        </div>
        <template #extra>
          <a-button type="primary" size="small" @click="fetchLogs">{{ $t('Refresh') }}</a-button>
        </template>
      </tlt-card>
    </a-tab-pane>
  </a-tabs>
</template>

<script>
export default {
  props: {
    tab: {
      type: String,
      default: 'general'
    }
  },
  data() {
    return {
      activeTab: this.tab || 'general',
      logContent: "",
      rfConfOptions: [],
      rssiTcompOptions: [],
      credOptions: [
        ["tc", this.$t("TC")],
        ["cups", this.$t("CUPS")],
      ],
      modeOptions: [
        ["no", this.$t("No Authentication")],
        ["server", this.$t("TLS Server Authentication")],
        ["serverAndClient", this.$t("TLS Server and Client Authentication")],
        ["serverAndClientToken", this.$t("TLS Server Authentication and Client Token")],
      ],
      logLevelOptions: [
        ["XDEBUG", "xdebug"],
        ["DEBUG", "debug"],
        ["VERBOSE", "verbose"],
        ["INFO", "info"],
        ["NOTICE", "notice"],
        ["WARNING", "warning"],
        ["ERROR", "error"],
        ["CRITICAL", "critical"],
      ],
      rfConfColumns: [
        { name: "type", label: this.$t("Type") },
        { name: "txEnable", label: this.$t("Tx enable") },
        { name: "freq", label: this.$t("Frequency") },
        { name: "antennaGain", label: this.$t("Antenna Gain") },
        { name: "rssiOffset", label: this.$t("RSSI Offset") },
        { name: "useRssiTcomp", label: this.$t("RSSI Tcomp") },
      ],
      rssiTcompColumns: [
        { name: "coeff_a", label: this.$t("Coeff A") },
        { name: "coeff_b", label: this.$t("Coeff B") },
        { name: "coeff_c", label: this.$t("Coeff C") },
        { name: "coeff_d", label: this.$t("Coeff D") },
        { name: "coeff_e", label: this.$t("Coeff E") },
      ],
      txLutColumns: [
        { name: "rfPower", label: this.$t("RF Power") },
        { name: "paGain", label: this.$t("PA Enable") },
        { name: "pwrIdx", label: this.$t("Power Index") },
        { name: "usedBy", label: this.$t("Used By") },
      ],
    };
  },
  async created() {
    await this.loadUciOptions();
    await this.fetchLogs();
  },
  methods: {
    async loadUciOptions() {
      await this.$uci.load("basicstation");
      this.rfConfOptions = this.$uci.sections("basicstation", "rfconf").map(s => [s['.name'], s['.name']]);
      this.rssiTcompOptions = this.$uci.sections("basicstation", "rssitcomp").map(s => [s['.name'], s['.name']]);
    },
    async fetchLogs() {
      this.$spin();
      try {
        const response = await this.$axios.get("/api/basicstation/services/basicstation/log");
        this.logContent = response.log;
      } catch (e) {
        this.$message.error(this.$t("Failed to fetch logs"));
      } finally {
        this.$spin(false);
      }
    },
  },
};
</script>

<style scoped>
.log-container {
  max-height: 500px;
  overflow-y: auto;
  background: #f5f5f5;
  padding: 10px;
  border-radius: 4px;
}
pre {
  white-space: pre-wrap;
  word-wrap: break-word;
  margin: 0;
}
.basicstation-tabs {
    padding: 24px;
}
</style>

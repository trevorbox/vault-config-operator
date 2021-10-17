/*
Copyright 2021.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	"context"
	"reflect"

	vaultutils "github.com/redhat-cop/vault-config-operator/api/v1alpha1/utils"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// KubernetesAuthEngineConfigSpec defines the desired state of KubernetesAuthEngineConfig
type KubernetesAuthEngineConfigSpec struct {
	// Authentication is the kube aoth configuraiton to be used to execute this request
	// +kubebuilder:validation:Required
	Authentication KubeAuthConfiguration `json:"authentication,omitempty"`

	// Path at which to make the configuration.
	// The final path will be {[spec.authentication.namespace]}/auth/{spec.path}/config/{metadata.name}.
	// The authentication role must have the following capabilities = [ "create", "read", "update", "delete"] on that path.
	// +kubebuilder:validation:Required
	Path Path `json:"path,omitempty"`

	KAECConfig `json:",inline"`
}

func (d *KubernetesAuthEngineConfig) GetPath() string {
	return cleansePath("auth/" + string(d.Spec.Path) + "/role/" + d.Name)
}

func (d *KubernetesAuthEngineConfig) GetPayload() map[string]interface{} {
	return d.Spec.KAECConfig.ToMap()
}
func (d *KubernetesAuthEngineConfig) IsEquivalentToDesiredState(payload map[string]interface{}) bool {
	desiredState := d.Spec.KAECConfig.ToMap()
	return reflect.DeepEqual(desiredState, payload)
}

var _ vaultutils.VaultObject = &KubernetesAuthEngineConfig{}

func (d *KubernetesAuthEngineConfig) IsInitialized() bool {
	return d.Spec.Authentication.IsInitialized()
}

func (d *KubernetesAuthEngineConfig) PrepareInternalValues(context context.Context, object client.Object) error {
	return nil
}

func (r *KubernetesAuthEngineConfig) IsValid() (bool, error) {
	return true, nil
}

type KAECConfig struct {

	// KubernetesHost Host must be a host string, a host:port pair, or a URL to the base of the Kubernetes API server.
	// +kubebuilder:validation:Required
	KubernetesHost string `json:"kubernetesHost,omitempty"`

	// kubernetesCACert PEM encoded CA cert for use by the TLS client used to talk with the Kubernetes API. NOTE: Every line must end with a newline: \n
	// +kubebuilder:validation:Required
	KubernetesCACert string `json:"kubernetesCACert,omitempty"`

	// TokenReviewerJWT A service account JWT used to access the TokenReview API to validate other JWTs during login. If not set, the JWT submitted in the login payload will be used to access the Kubernetes TokenReview API.
	// +kubebuilder:validation:Required
	TokenReviewerJWT string `json:"tokenReviewerJWT,omitempty"`

	// PEMKeys Optional list of PEM-formatted public keys or certificates used to verify the signatures of Kubernetes service account JWTs. If a certificate is given, its public key will be extracted. Not every installation of Kubernetes exposes these keys.
	// +kubebuilder:validation:Optional
	PEMKeys []string `json:"pEMKeys,omitempty"`

	// Issuer Optional JWT issuer. If no issuer is specified, then this plugin will use kubernetes/serviceaccount as the default issuer. See these instructions for looking up the issuer for a given Kubernetes cluster.
	// +kubebuilder:validation:Optional
	Issuer string `json:"issuer,omitempty"`

	// DisableISSValidation Disable JWT issuer validation. Allows to skip ISS validation.
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=false
	DisableISSValidation bool

	// DisableLoaclCAJWT Disable defaulting to the local CA cert and service account JWT when running in a Kubernetes pod.
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=false
	DisableLoaclCAJWT bool
}

// KubernetesAuthEngineConfigStatus defines the observed state of KubernetesAuthEngineConfig
type KubernetesAuthEngineConfigStatus struct {

	// +patchMergeKey=type
	// +patchStrategy=merge
	// +listType=map
	// +listMapKey=type
	Conditions []metav1.Condition `json:"conditions,omitempty" patchStrategy:"merge" patchMergeKey:"type"`
}

func (m *KubernetesAuthEngineConfig) GetConditions() []metav1.Condition {
	return m.Status.Conditions
}

func (m *KubernetesAuthEngineConfig) SetConditions(conditions []metav1.Condition) {
	m.Status.Conditions = conditions
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// KubernetesAuthEngineConfig is the Schema for the kubernetesauthengineconfigs API
type KubernetesAuthEngineConfig struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   KubernetesAuthEngineConfigSpec   `json:"spec,omitempty"`
	Status KubernetesAuthEngineConfigStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// KubernetesAuthEngineConfigList contains a list of KubernetesAuthEngineConfig
type KubernetesAuthEngineConfigList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []KubernetesAuthEngineConfig `json:"items"`
}

func init() {
	SchemeBuilder.Register(&KubernetesAuthEngineConfig{}, &KubernetesAuthEngineConfigList{})
}

func KAECConfigFromMap(payload map[string]interface{}) *KAECConfig {
	o := &KAECConfig{}
	o.KubernetesHost = payload["kubernetes_host"].(string)
	o.KubernetesCACert = payload["kubernetes_ca_host"].(string)
	o.TokenReviewerJWT = payload["token_reviewer_jwt"].(string)
	o.PEMKeys = payload["pem_keys"].([]string)
	o.Issuer = payload["issuer"].(string)
	o.DisableISSValidation = payload["disable_iss_validation"].(bool)
	o.DisableLoaclCAJWT = payload["disable_local_ca_jwt"].(bool)
	return o
}

func (i *KAECConfig) ToMap() map[string]interface{} {
	payload := map[string]interface{}{}
	payload["kubernetes_host"] = i.KubernetesHost
	payload["kubernetes_ca_host"] = i.KubernetesCACert
	payload["token_reviewer_jwt"] = i.TokenReviewerJWT
	payload["pem_keys"] = i.PEMKeys
	payload["issuer"] = i.Issuer
	payload["disable_iss_validation"] = i.DisableISSValidation
	payload["disable_local_ca_jwt"] = i.DisableLoaclCAJWT
	return payload
}

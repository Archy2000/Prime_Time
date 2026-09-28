using UnityEngine;

public class BasicFracture : MonoBehaviour
{
	public float breakForce = 100f;

	public GameObject fracturedObject;

	private void OnCollisionEnter(Collision collision)
	{
		if (collision.impulse.magnitude > breakForce)
		{
			fracturedObject.SetActive(value: true);
			fracturedObject.transform.parent = null;
			Object.Destroy(gameObject);
		}
	}
}

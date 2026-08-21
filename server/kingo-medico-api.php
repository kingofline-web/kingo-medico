<?php
/**
 * Plugin Name: KINGO Medico API
 * Description: Endpoint REST server-side per la chat KINGO Medico.
 * Version: 1.0.0
 */

if (!defined('ABSPATH')) exit;

add_action('rest_api_init', function () {
    register_rest_route('kingo-medico/v1', '/chat', [
        'methods'  => 'POST',
        'callback' => 'kingo_medico_chat',
        'permission_callback' => '__return_true',
    ]);
});

function kingo_medico_chat(WP_REST_Request $request) {
    $message = sanitize_textarea_field((string) $request->get_param('message'));
    $history = $request->get_param('history');

    if ($message === '') {
        return new WP_REST_Response(['message' => 'Messaggio vuoto.'], 400);
    }

    $api_key = defined('KINGO_MEDICO_OPENAI_API_KEY')
        ? KINGO_MEDICO_OPENAI_API_KEY
        : getenv('KINGO_MEDICO_OPENAI_API_KEY');

    if (!$api_key) {
        return new WP_REST_Response([
            'message' => 'Il servizio AI non è ancora configurato sul server.'
        ], 503);
    }

    $input = [];

    if (is_array($history)) {
        foreach (array_slice($history, -12) as $item) {
            if (!is_array($item)) continue;
            $role = isset($item['role']) && $item['role'] === 'assistant'
                ? 'assistant'
                : 'user';
            $content = isset($item['content'])
                ? sanitize_textarea_field((string) $item['content'])
                : '';
            if ($content !== '') {
                $input[] = ['role' => $role, 'content' => $content];
            }
        }
    }

    $input[] = ['role' => 'user', 'content' => $message];

    $instructions = implode("\n", [
        'Sei KINGO Medico, assistente sanitario informativo in lingua italiana.',
        'Non presentare mai una risposta come diagnosi definitiva e non prescrivere o modificare terapie.',
        'Spiega in modo chiaro e prudente, evidenziando quando è opportuno contattare un medico.',
        'Se il contenuto suggerisce una possibile emergenza o sintomi potenzialmente gravi, dai priorità all’invito a contattare immediatamente i servizi di emergenza appropriati.',
        'Per esami e referti spiega i termini e i valori senza sostituirti al professionista sanitario.',
        'Fai domande di chiarimento solo quando servono davvero.',
    ]);

    $response = wp_remote_post('https://api.openai.com/v1/responses', [
        'timeout' => 60,
        'headers' => [
            'Authorization' => 'Bearer ' . $api_key,
            'Content-Type'  => 'application/json',
        ],
        'body' => wp_json_encode([
            'model' => 'gpt-5.6',
            'instructions' => $instructions,
            'input' => $input,
            'store' => false,
        ]),
    ]);

    if (is_wp_error($response)) {
        return new WP_REST_Response([
            'message' => 'Errore di connessione al servizio AI.'
        ], 502);
    }

    $status = wp_remote_retrieve_response_code($response);
    $body = json_decode(wp_remote_retrieve_body($response), true);

    if ($status < 200 || $status >= 300) {
        return new WP_REST_Response([
            'message' => 'Il servizio AI ha restituito un errore.',
            'status' => $status,
        ], 502);
    }

    $reply = '';

    if (isset($body['output']) && is_array($body['output'])) {
        foreach ($body['output'] as $output_item) {
            if (!isset($output_item['content']) || !is_array($output_item['content'])) {
                continue;
            }
            foreach ($output_item['content'] as $content_item) {
                if (
                    isset($content_item['type']) &&
                    $content_item['type'] === 'output_text' &&
                    isset($content_item['text'])
                ) {
                    $reply .= (string) $content_item['text'];
                }
            }
        }
    }

    $reply = trim($reply);

    if ($reply === '') {
        return new WP_REST_Response([
            'message' => 'KINGO non ha ricevuto una risposta valida.'
        ], 502);
    }

    return new WP_REST_Response(['reply' => $reply], 200);
}
